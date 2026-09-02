"""High-level orchestration: fetch key -> encrypt -> send -> decrypt."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, List, Optional, Union

from .cache import FileKeyCache, KeyCache, MemoryKeyCache
from .config import SecureInvokeConfig
from .crypto import EncryptResult, SecureInvokeCrypto, get_default_crypto
from .errors import ConfigError
from .kms import KMSClient, PublicKey
from .native import NativeInvokeBackend
from .requests_io import RequestLike, load_batch_from_file, load_request
from .transport import build_transport
from .transport.base import Transport


def _build_key_cache(config: SecureInvokeConfig) -> Optional[KeyCache]:
    """Pick the default cache backend from config (None = caching disabled)."""
    if config.cache_file:
        return FileKeyCache(config.cache_file)
    if config.cache_keys:
        return MemoryKeyCache()
    return None


class SecureInvokeClient:
    """Encrypts, sends and decrypts offer requests.

    A single client instance is safe to reuse for many requests (and across
    threads): the KMS key cache, transport (HTTP session / gRPC channel) and
    crypto handle are all shared, which is what makes high-volume use efficient.
    """

    def __init__(
        self,
        config: SecureInvokeConfig,
        *,
        crypto: Optional[SecureInvokeCrypto] = None,
        transport: Optional[Transport] = None,
        key_cache: Optional[KeyCache] = None,
    ):
        config.validate()
        self.config = config
        self.backend = config.effective_backend()
        # Crypto (the vendored Azure ctypes lib) is only needed for the python
        # backend; loading it lazily lets the native/GCP path run on hosts that
        # don't have that library.
        self._crypto = crypto
        self._native: Optional[NativeInvokeBackend] = None
        # A caller-supplied cache (e.g. a Redis-backed KeyCache) wins; otherwise
        # build the default in-memory/on-disk cache from config (or None).
        self.key_cache = key_cache if key_cache is not None else _build_key_cache(config)
        self.kms = KMSClient(
            kms_host=config.kms_host,
            keys_endpoint=config.kms_keys_endpoint,
            timeout=config.timeout,
            insecure=config.insecure,
            client_cert=config.client_cert,
            client_key=config.client_key,
            ca_cert=config.ca_cert,
            cache=self.key_cache,
            cache_ttl=config.cache_ttl,
            respect_server_cache=config.cache_respect_server,
            verbose=config.verbose,
        )
        self._transport = transport

    # -- resources ----------------------------------------------------------

    @property
    def crypto(self) -> SecureInvokeCrypto:
        if self._crypto is None:
            self._crypto = get_default_crypto()
        return self._crypto

    @property
    def native(self) -> NativeInvokeBackend:
        if self._native is None:
            self._native = NativeInvokeBackend(self.config, self.kms)
        return self._native

    @property
    def transport(self) -> Transport:
        if self._transport is None:
            self._transport = build_transport(self.config)
        return self._transport

    def close(self) -> None:
        if self._transport is not None:
            self._transport.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # -- primitives ---------------------------------------------------------

    def public_key(self, force_refresh: bool = False) -> PublicKey:
        return self.kms.get_public_key(force_refresh=force_refresh)

    def encrypt(
        self,
        request: Union[RequestLike, None] = None,
        *,
        request_file: Optional[str] = None,
        public_key: Optional[PublicKey] = None,
    ) -> EncryptResult:
        if self.backend == "native":
            raise ConfigError(
                "standalone encrypt/decrypt is only available with the python "
                "backend; the native backend does the round trip in one step. "
                "Use op=invoke or set --backend python."
            )
        req = load_request(request, request_file)
        key = public_key or self.public_key()
        return self.crypto.encrypt(
            req, key.public_key, key.key_id, quiet=not self.config.verbose
        )

    def decrypt(self, response_ciphertext_b64: str, secret: str) -> Dict[str, Any]:
        return self.crypto.decrypt(
            response_ciphertext_b64, secret, quiet=not self.config.verbose
        )

    # -- end to end ---------------------------------------------------------

    def invoke(
        self,
        request: Union[RequestLike, None] = None,
        *,
        request_file: Optional[str] = None,
        public_key: Optional[PublicKey] = None,
    ) -> Dict[str, Any]:
        """Encrypt, send and decrypt a single request; return the response dict."""
        if self.backend == "native":
            return self.native.invoke(
                request, request_file=request_file, public_key=public_key
            )
        encrypted = self.encrypt(
            request, request_file=request_file, public_key=public_key
        )
        response_ciphertext = self.transport.send(encrypted)
        return self.crypto.decrypt(response_ciphertext, encrypted.secret)

    def invoke_batch(
        self,
        requests: List[RequestLike],
        *,
        max_workers: int = 8,
    ) -> List[Dict[str, Any]]:
        """Invoke many requests concurrently, reusing one key/transport.

        Returns a list (input order) of ``{"index", "response"}`` on success or
        ``{"index", "error"}`` on failure.
        """
        if self.backend == "native":
            return self.native.invoke_batch(requests, max_workers=max_workers)

        key = self.public_key()
        transport = self.transport

        quiet = not self.config.verbose

        def _run(index: int, req: RequestLike) -> Dict[str, Any]:
            try:
                encrypted = self.crypto.encrypt(
                    load_request(req), key.public_key, key.key_id, quiet=quiet
                )
                ciphertext = transport.send(encrypted)
                return {
                    "index": index,
                    "response": self.crypto.decrypt(
                        ciphertext, encrypted.secret, quiet=quiet
                    ),
                }
            except Exception as exc:  # noqa: BLE001 - report per-item failures
                return {"index": index, "error": str(exc)}

        with ThreadPoolExecutor(max_workers=max(1, max_workers)) as pool:
            results = list(pool.map(lambda pair: _run(*pair), enumerate(requests)))
        results.sort(key=lambda row: row["index"])
        return results

    def invoke_batch_file(
        self, path: str, *, max_workers: int = 8
    ) -> List[Dict[str, Any]]:
        """Load a ``.jsonl``/``.json`` batch file and invoke it concurrently."""
        return self.invoke_batch(load_batch_from_file(path), max_workers=max_workers)
