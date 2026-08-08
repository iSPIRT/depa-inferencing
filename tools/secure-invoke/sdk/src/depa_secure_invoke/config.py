"""Configuration for the DEPA secure-invoke SDK."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Optional

from .errors import ConfigError

DEFAULT_KMS_KEYS_ENDPOINT = "/app/listpubkeys"
DEFAULT_OFFER_ENDPOINT = "/v1/getbids"
DEFAULT_CACHE_TTL_SECONDS = 15 * 60  # 15 minutes
DEFAULT_TARGET_SERVICE = "bfe"

# Crypto/transport backends:
#   python -> pure-Python ctypes crypto + REST/gRPC transport. Works for the
#            Azure services (whose data-plane crypto matches the vendored
#            libsecure_invoke.so).
#   native -> drive the bundled native `invoke` binary as a subprocess. Required
#            for GCP, whose services are built from a different fork with a
#            different OHTTP/HPKE framing and ship only the monolithic binary
#            (no C-ABI shared library).
#   auto   -> pick per protocol: rest -> python, grpc -> native.
VALID_BACKENDS = ("auto", "python", "native")


@dataclass
class SecureInvokeConfig:
    """All tunables for a :class:`~depa_secure_invoke.client.SecureInvokeClient`.

    Hosts may include a path prefix (e.g. ``https://kms.example.com/tenant-a``);
    the configured endpoint is appended to it *without* discarding the prefix.
    """

    # --- KMS (public key service) ---
    kms_host: str = ""
    kms_keys_endpoint: str = DEFAULT_KMS_KEYS_ENDPOINT

    # --- Offer host (BFE / OFE) ---
    offer_host: str = ""
    offer_endpoint: str = DEFAULT_OFFER_ENDPOINT

    # rest  -> Azure (envoy transcodes JSON to gRPC)
    # grpc  -> GCP (no envoy; talk gRPC directly to BFE)
    protocol: str = "rest"

    # Crypto/transport backend (see VALID_BACKENDS above).
    backend: str = "auto"

    # --- native backend (GCP) ---
    # Service the native `invoke` binary targets (e.g. "bfe", "sfe").
    target_service: str = DEFAULT_TARGET_SERVICE
    # Explicit path to the native `invoke` binary. When unset it is resolved from
    # the SECURE_INVOKE_NATIVE_BIN env var, the packaged native/bin/invoke, then
    # PATH.
    native_bin: Optional[str] = None
    client_type: str = "browser"

    # --- TLS / security ---
    insecure: bool = False
    client_cert: Optional[str] = None
    client_key: Optional[str] = None
    ca_cert: Optional[str] = None

    # --- request behaviour ---
    headers: Dict[str, str] = field(default_factory=dict)
    retries: int = 1
    retry_delay: float = 2.0
    timeout: float = 20.0
    client_ip: Optional[str] = None

    # --- public key caching (opt-in, off by default) ---
    # cache_keys  -> enable the in-process (memory) cache.
    # cache_file  -> enable an on-disk cache at this path, shared across separate
    #                CLI invocations/processes (implies caching). Takes precedence
    #                over cache_keys when both are set.
    # cache_ttl   -> fallback lifetime (seconds) used when the KMS response has no
    #                Cache-Control/Expires header.
    # cache_respect_server -> honor the KMS response Cache-Control/Expires (and
    #                no-store/no-cache); set False to always use cache_ttl.
    # A custom cache backend (e.g. Redis) can be injected via
    # SecureInvokeClient(key_cache=...); see depa_secure_invoke.cache.
    cache_keys: bool = False
    cache_file: Optional[str] = None
    cache_ttl: int = DEFAULT_CACHE_TTL_SECONDS
    cache_respect_server: bool = True

    # --- diagnostics ---
    verbose: bool = False

    def validate(self) -> None:
        if not self.kms_host:
            raise ConfigError("kms_host is required")
        if not self.offer_host:
            raise ConfigError("offer_host is required")
        if self.protocol not in ("rest", "grpc"):
            raise ConfigError(f"protocol must be 'rest' or 'grpc', got {self.protocol!r}")
        if self.backend not in VALID_BACKENDS:
            raise ConfigError(
                f"backend must be one of {VALID_BACKENDS}, got {self.backend!r}"
            )
        if self.cache_ttl < 0:
            raise ConfigError(f"cache_ttl must be >= 0, got {self.cache_ttl}")
        if not self.insecure:
            # Client certs are only meaningful when TLS verification is on. We do
            # not force them (a public KMS/offer host over standard TLS is valid),
            # but if one half of the mTLS pair is given, require the other.
            if bool(self.client_cert) != bool(self.client_key):
                raise ConfigError(
                    "client_cert and client_key must be provided together"
                )

    def effective_backend(self) -> str:
        """Resolve the ``auto`` backend to a concrete choice.

        ``auto`` maps REST to the pure-Python (ctypes) crypto path and gRPC to
        the native binary, which are the combinations that are wire-compatible
        with the Azure and GCP services respectively.
        """
        if self.backend != "auto":
            return self.backend
        return "native" if self.protocol == "grpc" else "python"
