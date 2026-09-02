"""Pluggable public-key caching for the KMS client.

Caching is **off by default**. When enabled, fetched KMS public keys are reused
until they expire, so a client sending many requests doesn't hit the KMS every
time. The lifetime is driven by the KMS response's ``Cache-Control``/``Expires``
headers when present, otherwise by a configured fallback TTL (see
:class:`~depa_secure_invoke.kms.KMSClient`).

Storage is pluggable via the :class:`KeyCache` interface. Built-ins:

* :class:`MemoryKeyCache` - in-process (per client). Benefits library reuse and
  ``--op batch``, but not separate CLI invocations (each is a fresh process).
* :class:`FileKeyCache` - JSON on disk, shared across separate CLI invocations.

For an external store (Redis, memcached, a config service, ...), implement
:class:`KeyCache` and pass it to ``SecureInvokeClient(key_cache=...)``. See
``examples/redis_key_cache.py``. Alternatively, manage caching entirely yourself:
fetch a key once with ``client.public_key()`` and pass it back per call via the
``public_key=`` argument of ``invoke``/``encrypt``.
"""

from __future__ import annotations

import json
import os
import tempfile
import threading
import time
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Tuple

from .keys import PublicKey


class KeyCache(ABC):
    """Interface for a KMS public-key cache.

    Implementations must be safe to share across threads. ``key`` is an opaque
    cache key (the SDK uses the fully-qualified KMS URL). ``ttl`` is the number
    of seconds the value should remain valid; implementations must treat
    ``ttl <= 0`` as "do not store".
    """

    @abstractmethod
    def get(self, key: str) -> Optional[List[PublicKey]]:
        """Return the cached keys for ``key`` if present and unexpired, else None."""

    @abstractmethod
    def set(self, key: str, value: List[PublicKey], ttl: int) -> None:
        """Store ``value`` for ``key`` for ``ttl`` seconds (no-op if ttl <= 0)."""


def _to_public_keys(items) -> List[PublicKey]:
    return [
        PublicKey(key_id=str(i["key_id"]), public_key=str(i["public_key"]))
        for i in items
    ]


class MemoryKeyCache(KeyCache):
    """Thread-safe in-process TTL cache (default when caching is enabled)."""

    def __init__(self) -> None:
        self._data: Dict[str, Tuple[float, List[PublicKey]]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> Optional[List[PublicKey]]:
        with self._lock:
            entry = self._data.get(key)
            if entry is None:
                return None
            expiry, value = entry
            if time.monotonic() >= expiry:
                self._data.pop(key, None)
                return None
            return list(value)

    def set(self, key: str, value: List[PublicKey], ttl: int) -> None:
        if ttl <= 0:
            return
        with self._lock:
            self._data[key] = (time.monotonic() + ttl, list(value))


class FileKeyCache(KeyCache):
    """JSON-on-disk cache, shared across separate processes/CLI invocations.

    Uses wall-clock expiry (so it survives across processes) and atomic writes.
    Concurrent writers are best-effort: a lost write only causes an extra KMS
    fetch, never a stale/incorrect key.
    """

    def __init__(self, path: str) -> None:
        self.path = os.path.abspath(os.path.expanduser(path))
        self._lock = threading.Lock()

    def _read_all(self) -> Dict[str, dict]:
        try:
            with open(self.path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, dict):
                return data
        except (OSError, ValueError):
            pass
        return {}

    def _write_all(self, data: Dict[str, dict]) -> None:
        directory = os.path.dirname(self.path) or "."
        os.makedirs(directory, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=directory, suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(data, handle)
            os.replace(tmp, self.path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    def get(self, key: str) -> Optional[List[PublicKey]]:
        now = time.time()
        with self._lock:
            entry = self._read_all().get(key)
        if not entry or now >= float(entry.get("expiry", 0)):
            return None
        return _to_public_keys(entry.get("keys", []))

    def set(self, key: str, value: List[PublicKey], ttl: int) -> None:
        if ttl <= 0:
            return
        now = time.time()
        with self._lock:
            data = self._read_all()
            # Drop expired entries while we're here.
            data = {
                k: v for k, v in data.items() if float(v.get("expiry", 0)) > now
            }
            data[key] = {
                "expiry": now + ttl,
                "keys": [dict(v) for v in value],
            }
            self._write_all(data)
