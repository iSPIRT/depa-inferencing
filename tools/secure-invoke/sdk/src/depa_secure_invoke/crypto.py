"""Thin ctypes wrapper around the prebuilt B&A crypto libraries.

The two vendored shared objects are the *exact same* crypto implementation used
by the offer services, so payloads encrypted here can be decrypted server-side
(and vice-versa):

* ``libsecure_invoke.so`` - exports the C ABI we call
  (``secure_invoke_init/encrypt/decrypt/free_result/get_version/cleanup``).
* ``libcddl.so`` - a runtime dependency of ``libsecure_invoke.so``.

``libsecure_invoke.so`` declares ``libcddl.so`` as ``NEEDED`` but its embedded
``RUNPATH`` points at Bazel build directories that do not exist once the file is
vendored into the wheel. Instead of relying on ``LD_LIBRARY_PATH`` (which made
the previous SDK fragile), we explicitly ``dlopen`` ``libcddl.so`` with
``RTLD_GLOBAL`` first, so its symbols are already resolved when the loader wires
up ``libsecure_invoke.so``.
"""

from __future__ import annotations

import base64
import contextlib
import ctypes
import json
import os
import sys
import threading
from ctypes import POINTER, Structure, c_char_p, c_int
from typing import Any, Dict, NamedTuple, Optional, Tuple, Union

from .errors import CryptoError

_ENCRYPT_SECRET_DELIMITER = "|||SECRET|||"
# proto3 JSON (lowerCamelCase) field names produced/consumed by the C++ lib.
_CIPHERTEXT_KEYS = ("requestCiphertext", "request_ciphertext", "ciphertext")
_KEY_ID_KEYS = ("keyId", "key_id")


class _Result(Structure):
    _fields_ = [
        ("success", c_int),
        ("response", c_char_p),
        ("error_message", c_char_p),
    ]


class EncryptResult(NamedTuple):
    """Output of :meth:`SecureInvokeCrypto.encrypt`.

    ``payload`` is the JSON body the C++ lib emits (used verbatim as the REST
    body). ``ciphertext_b64``/``key_id`` are parsed out of it for the gRPC path.
    ``secret`` must be supplied back to :meth:`SecureInvokeCrypto.decrypt`.
    """

    payload: str
    ciphertext_b64: str
    key_id: str
    secret: str

    @property
    def ciphertext_bytes(self) -> bytes:
        return base64.b64decode(self.ciphertext_b64)


def _lib_dir() -> str:
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib")


@contextlib.contextmanager
def _suppress_native_stdout(enabled: bool):
    """Temporarily silence the C library's ``printf`` debug output (fd 1).

    The crypto library writes progress/debug lines straight to file descriptor 1,
    which would corrupt the SDK's JSON output. Python-level stdout swapping does
    not catch these, so we redirect the OS file descriptor itself.
    """
    if not enabled:
        yield
        return
    sys.stdout.flush()
    saved_fd = os.dup(1)
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    try:
        os.dup2(devnull_fd, 1)
        yield
    finally:
        os.dup2(saved_fd, 1)
        os.close(devnull_fd)
        os.close(saved_fd)


class SecureInvokeCrypto:
    """Loads the crypto libraries once and exposes encrypt/decrypt.

    A single instance is safe to share across threads: the underlying C library
    keeps global state, so all FFI calls are serialised behind a lock.
    """

    def __init__(self, lib_dir: Optional[str] = None):
        self._lock = threading.Lock()
        self._lib: Optional[ctypes.CDLL] = None
        self._cddl: Optional[ctypes.CDLL] = None
        self._initialised = False
        self._load(lib_dir or _lib_dir())

    def _load(self, lib_dir: str) -> None:
        cddl_path = os.path.join(lib_dir, "libcddl.so")
        main_path = os.path.join(lib_dir, "libsecure_invoke.so")
        for path in (cddl_path, main_path):
            if not os.path.isfile(path):
                raise CryptoError(
                    f"crypto library not found: {path}. The heavy binaries are not "
                    "committed; fetch them from the container registry with "
                    "scripts/fetch_libs.sh (or set SECURE_INVOKE_LIBS_REF)."
                )

        try:
            # Preload the dependency into the global symbol namespace so the
            # loader can resolve libsecure_invoke.so without LD_LIBRARY_PATH.
            self._cddl = ctypes.CDLL(cddl_path, mode=ctypes.RTLD_GLOBAL)
            self._lib = ctypes.CDLL(main_path, mode=ctypes.RTLD_GLOBAL)
        except OSError as exc:
            raise CryptoError(f"failed to load crypto library: {exc}") from exc

        self._bind_signatures()

        if not self._lib.secure_invoke_init():
            raise CryptoError("secure_invoke_init() failed")
        self._initialised = True

    def _bind_signatures(self) -> None:
        lib = self._lib
        assert lib is not None
        lib.secure_invoke_init.argtypes = []
        lib.secure_invoke_init.restype = c_int
        lib.secure_invoke_cleanup.argtypes = []
        lib.secure_invoke_cleanup.restype = None
        lib.secure_invoke_encrypt.argtypes = [c_char_p, c_char_p, c_char_p]
        lib.secure_invoke_encrypt.restype = POINTER(_Result)
        lib.secure_invoke_decrypt.argtypes = [c_char_p, c_char_p]
        lib.secure_invoke_decrypt.restype = POINTER(_Result)
        lib.secure_invoke_free_result.argtypes = [POINTER(_Result)]
        lib.secure_invoke_free_result.restype = None
        lib.secure_invoke_get_version.argtypes = []
        lib.secure_invoke_get_version.restype = c_char_p

    # -- public API ---------------------------------------------------------

    def version(self) -> str:
        with self._lock:
            raw = self._lib.secure_invoke_get_version()
        return raw.decode("utf-8") if raw else "unknown"

    def encrypt(
        self,
        request: Union[Dict[str, Any], str],
        public_key: str,
        key_id: str,
        quiet: bool = True,
    ) -> EncryptResult:
        """Encrypt a plaintext GetBidsRawRequest.

        Args:
            request: request as a dict or JSON string.
            public_key: base64 public key from the KMS.
            key_id: key id from the KMS (hex or decimal).
            quiet: suppress the C library's stdout debug output.
        """
        if isinstance(request, dict):
            json_str = json.dumps(request)
        elif isinstance(request, str):
            try:
                json.loads(request)
            except json.JSONDecodeError as exc:
                raise CryptoError(f"request is not valid JSON: {exc}") from exc
            json_str = request
        else:
            raise CryptoError(
                f"request must be dict or JSON string, got {type(request).__name__}"
            )

        # The C++ lib expects the key id as a decimal string.
        try:
            decimal_key_id = str(int(key_id, 16))
        except (ValueError, TypeError):
            decimal_key_id = str(key_id)

        with self._lock, _suppress_native_stdout(quiet):
            ptr = self._lib.secure_invoke_encrypt(
                json_str.encode("utf-8"),
                public_key.encode("utf-8"),
                decimal_key_id.encode("utf-8"),
            )
            response = self._consume(ptr, "encrypt")

        delimiter_pos = response.find(_ENCRYPT_SECRET_DELIMITER)
        if delimiter_pos == -1:
            raise CryptoError("secret delimiter missing from encrypt response")
        payload = response[:delimiter_pos]
        secret = response[delimiter_pos + len(_ENCRYPT_SECRET_DELIMITER):]

        ciphertext_b64, parsed_key_id = _parse_payload(payload)
        return EncryptResult(
            payload=payload,
            ciphertext_b64=ciphertext_b64,
            key_id=parsed_key_id or str(key_id),
            secret=secret,
        )

    def decrypt(self, ciphertext_b64: str, secret: str, quiet: bool = True) -> Dict[str, Any]:
        """Decrypt a base64 response ciphertext into a JSON dict."""
        with self._lock, _suppress_native_stdout(quiet):
            ptr = self._lib.secure_invoke_decrypt(
                ciphertext_b64.encode("utf-8"),
                secret.encode("utf-8"),
            )
            response = self._consume(ptr, "decrypt")
        try:
            return json.loads(response)
        except json.JSONDecodeError as exc:
            raise CryptoError(f"decrypted response is not valid JSON: {exc}") from exc

    # -- internals ----------------------------------------------------------

    def _consume(self, ptr, op: str) -> str:
        if not ptr:
            raise CryptoError(f"secure_invoke_{op} returned null")
        try:
            result = ptr.contents
            if not result.success:
                msg = (
                    result.error_message.decode("utf-8")
                    if result.error_message
                    else "unknown error"
                )
                raise CryptoError(f"{op} failed: {msg}")
            if not result.response:
                raise CryptoError(f"{op} succeeded but returned no data")
            return result.response.decode("utf-8")
        finally:
            self._lib.secure_invoke_free_result(ptr)

    def close(self) -> None:
        with self._lock:
            if self._lib is not None and self._initialised:
                self._lib.secure_invoke_cleanup()
                self._initialised = False

    def __del__(self):  # best-effort cleanup
        try:
            self.close()
        except Exception:
            pass


def _parse_payload(payload: str) -> Tuple[str, Optional[str]]:
    """Extract (ciphertext_b64, key_id) from the REST body emitted by the lib."""
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        # Not JSON: treat the whole payload as the ciphertext.
        return payload, None
    if not isinstance(data, dict):
        return payload, None
    ciphertext = _first_present(data, _CIPHERTEXT_KEYS)
    if ciphertext is None:
        raise CryptoError(
            f"could not find ciphertext in encrypt payload (keys: {list(data)})"
        )
    key_id = _first_present(data, _KEY_ID_KEYS)
    return str(ciphertext), (str(key_id) if key_id is not None else None)


def _first_present(data: Dict[str, Any], keys) -> Optional[Any]:
    for key in keys:
        if key in data and data[key] not in (None, ""):
            return data[key]
    return None


_default_lock = threading.Lock()
_default_instance: Optional[SecureInvokeCrypto] = None


def get_default_crypto() -> SecureInvokeCrypto:
    """Return a lazily-created process-wide crypto instance."""
    global _default_instance
    with _default_lock:
        if _default_instance is None:
            _default_instance = SecureInvokeCrypto()
        return _default_instance
