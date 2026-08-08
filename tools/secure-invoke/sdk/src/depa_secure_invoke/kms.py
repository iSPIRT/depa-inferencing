"""KMS client: fetches public keys used to encrypt offer requests.

Improvements over the previous SDK:

* Path-preserving URL join (see :mod:`depa_secure_invoke.urls`).
* Defaults to the production ``/app/listpubkeys`` route (all KMS endpoints are
  served under ``/app/*``); the sandbox ``/listpubkeys`` is no longer assumed.
* Optional, opt-in public-key caching (see :mod:`depa_secure_invoke.cache`). The
  cache lifetime honors the KMS response's ``Cache-Control: max-age`` / ``Expires``
  (and ``no-store``/``no-cache``) when present, falling back to a configured TTL
  (default 15 minutes). When caching is enabled a ``Cache-Control: max-age=<ttl>``
  request header is also sent so intermediary caches can cooperate.
"""

from __future__ import annotations

import re
import time
from datetime import timezone
from email.utils import parsedate_to_datetime
from typing import List, Optional, Tuple

import requests
import urllib3

from .cache import KeyCache
from .errors import KMSError
from .keys import PublicKey
from .urls import join_url

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

_MAX_AGE_RE = re.compile(r"max-age\s*=\s*(\d+)")


class KMSClient:
    def __init__(
        self,
        kms_host: str,
        keys_endpoint: str = "/app/listpubkeys",
        *,
        timeout: float = 30.0,
        insecure: bool = False,
        client_cert: Optional[str] = None,
        client_key: Optional[str] = None,
        ca_cert: Optional[str] = None,
        cache: Optional[KeyCache] = None,
        cache_ttl: int = 15 * 60,
        respect_server_cache: bool = True,
        verbose: bool = False,
    ):
        self.url = join_url(kms_host, keys_endpoint, default_scheme="https")
        self.timeout = timeout
        self.insecure = insecure
        self.cache = cache
        self.cache_ttl = cache_ttl
        self.respect_server_cache = respect_server_cache
        self.verbose = verbose

        self.session = requests.Session()
        self.session.headers.update(
            {"Content-Type": "application/json", "Accept": "application/json"}
        )
        if cache is not None:
            # Advertise our freshness tolerance to any intermediary caches.
            self.session.headers["Cache-Control"] = f"max-age={cache_ttl}"

        self._configure_tls(insecure, client_cert, client_key, ca_cert)

    def _configure_tls(self, insecure, client_cert, client_key, ca_cert) -> None:
        if insecure:
            self.session.verify = False
        elif ca_cert:
            self.session.verify = ca_cert
        else:
            self.session.verify = True
        if client_cert and client_key:
            self.session.cert = (client_cert, client_key)
        elif client_cert:
            self.session.cert = client_cert

    def _log(self, msg: str) -> None:
        if self.verbose:
            print(f"[kms] {msg}")

    def list_public_keys(self, force_refresh: bool = False) -> List[PublicKey]:
        """Return the KMS public keys, using the cache when enabled/valid."""
        if self.cache is not None and not force_refresh:
            cached = self.cache.get(self.url)
            if cached:
                self._log("using cached public keys")
                return cached

        keys, ttl = self._fetch()

        if self.cache is not None and ttl is not None and ttl > 0:
            self._log(f"caching {len(keys)} key(s) for {ttl}s")
            self.cache.set(self.url, keys, ttl)
        return keys

    def get_public_key(self, force_refresh: bool = False) -> PublicKey:
        """Return the first available public key."""
        keys = self.list_public_keys(force_refresh=force_refresh)
        if not keys:
            raise KMSError("no public keys returned by KMS")
        return keys[0]

    def _fetch(self) -> Tuple[List[PublicKey], Optional[int]]:
        self._log(f"fetching public keys from {self.url}")
        try:
            resp = self.session.get(self.url, timeout=self.timeout)
            resp.raise_for_status()
        except requests.exceptions.RequestException as exc:
            raise KMSError(f"failed to fetch keys from {self.url}: {exc}") from exc

        try:
            data = resp.json()
        except ValueError as exc:
            raise KMSError(f"invalid JSON from KMS: {exc}") from exc

        raw_keys = data.get("keys") if isinstance(data, dict) else None
        if not raw_keys:
            raise KMSError(f"no 'keys' field in KMS response from {self.url}")

        keys: List[PublicKey] = []
        for i, item in enumerate(raw_keys):
            try:
                keys.append(
                    PublicKey(key_id=str(item["id"]), public_key=str(item["key"]))
                )
            except (KeyError, TypeError) as exc:
                self._log(f"skipping malformed key {i}: {exc}")
        if not keys:
            raise KMSError("KMS response contained no valid keys")
        self._log(f"fetched {len(keys)} key(s)")
        return keys, self._resolve_ttl(resp)

    def _resolve_ttl(self, resp: requests.Response) -> Optional[int]:
        """Decide how long to cache, honoring server cache headers.

        Returns the TTL in seconds, or ``None`` to mean "do not cache". When
        ``respect_server_cache`` is off, the configured fallback TTL is always
        used.
        """
        if not self.respect_server_cache:
            return self.cache_ttl

        cache_control = resp.headers.get("Cache-Control", "").lower()
        if "no-store" in cache_control or "no-cache" in cache_control:
            self._log("KMS response is no-store/no-cache; not caching")
            return None

        match = _MAX_AGE_RE.search(cache_control)
        if match:
            return int(match.group(1))

        expires = resp.headers.get("Expires")
        if expires:
            try:
                parsed = parsedate_to_datetime(expires)
                if parsed is not None:
                    # HTTP dates are GMT; if the tz is unknown/naive, assume UTC
                    # so .timestamp() isn't skewed by the local timezone.
                    if parsed.tzinfo is None:
                        parsed = parsed.replace(tzinfo=timezone.utc)
                    return max(0, int(parsed.timestamp() - time.time()))
            except (TypeError, ValueError, OverflowError):
                pass

        return self.cache_ttl


__all__ = ["KMSClient", "PublicKey"]
