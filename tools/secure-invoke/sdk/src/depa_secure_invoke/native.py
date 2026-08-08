"""Native backend: drive the bundled ``invoke`` binary as a subprocess.

The GCP bidding/auction services are built from a different fork than the Azure
services and use a different data-plane crypto (OHTTP/HPKE framing). That fork
ships only the monolithic ``invoke`` tool -- there is no C-ABI shared library to
ctypes-wrap. To stay wire-compatible with GCP while keeping a single Python SDK
surface, the GCP path shells out to that native binary.

Key management (fetching the public key + key id from the KMS, with the correct
``/app/listpubkeys`` route, path preservation and optional caching) is still done
in Python via :class:`~depa_secure_invoke.kms.KMSClient`; only the
encrypt -> send -> decrypt round trip is delegated to the binary.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, List, Optional

from .config import SecureInvokeConfig
from .errors import ConfigError, TransportError
from .kms import KMSClient, PublicKey
from .requests_io import RequestLike, load_request

_PACKAGE_DIR = os.path.dirname(os.path.abspath(__file__))
_BUNDLED_BIN = os.path.join(_PACKAGE_DIR, "native", "bin", "invoke")
_BUNDLED_LIB = os.path.join(_PACKAGE_DIR, "native", "lib")


def resolve_native_bin(explicit: Optional[str] = None) -> str:
    """Locate the native ``invoke`` binary.

    Resolution order: explicit path -> ``SECURE_INVOKE_NATIVE_BIN`` env var ->
    the binary bundled with this package -> ``invoke`` on ``PATH``.
    """
    candidates = [
        explicit,
        os.environ.get("SECURE_INVOKE_NATIVE_BIN"),
        _BUNDLED_BIN if os.path.isfile(_BUNDLED_BIN) else None,
        shutil.which("invoke"),
    ]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    raise ConfigError(
        "native 'invoke' binary not found. Set SECURE_INVOKE_NATIVE_BIN, bundle it "
        "at native/bin/invoke, or put it on PATH. See scripts/fetch_native.sh to "
        "extract it from the GCP secure_invoke image."
    )


def _extract_json(text: str) -> Any:
    """Pull the JSON response out of the binary's stdout.

    In quiet mode stdout is exactly the response payload, but verbose/log output
    can prepend lines, so fall back to scanning for the last balanced JSON value.
    """
    text = text.strip()
    if not text:
        raise TransportError("native invoke produced no output")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Scan for the last top-level JSON object/array in the output.
    for opener, closer in (("{", "}"), ("[", "]")):
        start = text.find(opener)
        end = text.rfind(closer)
        if start != -1 and end > start:
            snippet = text[start : end + 1]
            try:
                return json.loads(snippet)
            except json.JSONDecodeError:
                continue
    raise TransportError(f"could not parse JSON from native invoke output: {text[:500]}")


class NativeInvokeBackend:
    """Wraps the native ``invoke`` binary for the GCP (and REST) crypto path."""

    def __init__(self, config: SecureInvokeConfig, kms: KMSClient):
        self.config = config
        self.kms = kms
        self.bin = resolve_native_bin(config.native_bin)
        # The binary loads its own libcddl.so via RUNPATH ($ORIGIN/../lib); when
        # bundled we still export the lib dir so it works from any CWD.
        self._env = dict(os.environ)
        if os.path.isdir(_BUNDLED_LIB):
            existing = self._env.get("LD_LIBRARY_PATH", "")
            self._env["LD_LIBRARY_PATH"] = (
                f"{_BUNDLED_LIB}:{existing}" if existing else _BUNDLED_LIB
            )

    # -- helpers ------------------------------------------------------------

    def _op(self) -> str:
        return "rest_invoke" if self.config.protocol == "rest" else "invoke"

    def _headers_arg(self) -> Optional[str]:
        if not self.config.headers:
            return None
        # Binary expects "key=value;key2=value2;" format.
        return "".join(f"{k}={v};" for k, v in self.config.headers.items())

    def _common_args(self, key: PublicKey) -> List[str]:
        cfg = self.config
        args = [
            f"-target_service={cfg.target_service}",
            f"-host_addr={cfg.offer_host}",
            f"-public_key={key.public_key}",
            f"-key_id={key.key_id}",
            f"-client_type={cfg.client_type}",
        ]
        if cfg.client_ip:
            args.append(f"-client_ip={cfg.client_ip}")
        if cfg.insecure:
            args.append("-insecure=true")
        headers = self._headers_arg()
        if headers:
            args.append(f"-headers={headers}")
        if cfg.client_key:
            args.append(f"-client_key={cfg.client_key}")
        if cfg.client_cert:
            args.append(f"-client_cert={cfg.client_cert}")
        if cfg.ca_cert:
            args.append(f"-ca_cert={cfg.ca_cert}")
        if cfg.verbose:
            args.append("-enable_verbose=true")
        return args

    def _run(self, args: List[str]) -> subprocess.CompletedProcess:
        cmd = [self.bin] + args
        if self.config.verbose:
            print(f"[native] {' '.join(cmd)}")
        try:
            return subprocess.run(
                cmd,
                env=self._env,
                capture_output=True,
                text=True,
                timeout=self.config.timeout * max(1, self.config.retries) + 30,
            )
        except subprocess.TimeoutExpired as exc:
            raise TransportError(f"native invoke timed out: {exc}") from exc
        except OSError as exc:
            raise TransportError(f"failed to run native invoke: {exc}") from exc

    # -- public API ---------------------------------------------------------

    def public_key(self, force_refresh: bool = False) -> PublicKey:
        return self.kms.get_public_key(force_refresh=force_refresh)

    def invoke(
        self,
        request: Optional[RequestLike] = None,
        *,
        request_file: Optional[str] = None,
        public_key: Optional[PublicKey] = None,
    ) -> Dict[str, Any]:
        """Run a single encrypt -> send -> decrypt round trip via the binary."""
        key = public_key or self.public_key()
        args = [f"-op={self._op()}"] + self._common_args(key)

        tmp_path: Optional[str] = None
        try:
            if request_file:
                args.append(f"-input_file={request_file}")
            else:
                payload = load_request(request)
                # json_input_str is awkward to quote safely; use a temp file.
                fd, tmp_path = tempfile.mkstemp(suffix=".json")
                with os.fdopen(fd, "w", encoding="utf-8") as handle:
                    json.dump(payload, handle)
                args.append(f"-input_file={tmp_path}")

            proc = self._run(args)
            if proc.returncode != 0:
                raise TransportError(
                    f"native invoke failed (exit {proc.returncode}): "
                    f"{(proc.stderr or proc.stdout).strip()[:1000]}"
                )
            return _extract_json(proc.stdout)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)

    def invoke_batch(
        self,
        requests: List[RequestLike],
        *,
        max_workers: int = 8,
    ) -> List[Dict[str, Any]]:
        """Invoke many requests concurrently, reusing one fetched key.

        The binary's own ``batch_invoke`` op is version-fragile (it aborts unless
        ``-input_file`` is also given), so we drive concurrent single invocations
        from Python instead. This keeps the result shape identical to the python
        backend: ``{"index", "response"}`` or ``{"index", "error"}``.
        """
        key = self.public_key()

        def _run(index: int, req: RequestLike) -> Dict[str, Any]:
            try:
                return {"index": index, "response": self.invoke(req, public_key=key)}
            except Exception as exc:  # noqa: BLE001 - report per-item failures
                return {"index": index, "error": str(exc)}

        with ThreadPoolExecutor(max_workers=max(1, max_workers)) as pool:
            results = list(pool.map(lambda pair: _run(*pair), enumerate(requests)))
        results.sort(key=lambda row: row["index"])
        return results

    def invoke_batch_file(
        self, path: str, *, max_workers: int = 8
    ) -> List[Dict[str, Any]]:
        from .requests_io import load_batch_from_file

        return self.invoke_batch(load_batch_from_file(path), max_workers=max_workers)
