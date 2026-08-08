"""DEPA Secure Invoke SDK.

Encrypt, send and decrypt DEPA inferencing (Bidding & Auction) offer requests
over REST (Azure) or gRPC (GCP), reusing the exact B&A C++ crypto libraries so
payloads round-trip with the offer services.

Example::

    from depa_secure_invoke import SecureInvokeClient, SecureInvokeConfig

    cfg = SecureInvokeConfig(
        kms_host="https://depa-inferencing-kms-azure.ispirt.in",
        offer_host="10.0.0.5:51052",
        protocol="rest",
        insecure=True,
    )
    with SecureInvokeClient(cfg) as client:
        response = client.invoke(request_file="get_bids_request.json")
        print(response)
"""

from ._version import __version__
from .client import SecureInvokeClient
from .config import (
    DEFAULT_CACHE_TTL_SECONDS,
    DEFAULT_KMS_KEYS_ENDPOINT,
    DEFAULT_OFFER_ENDPOINT,
    DEFAULT_TARGET_SERVICE,
    SecureInvokeConfig,
)
from .cache import FileKeyCache, KeyCache, MemoryKeyCache
from .crypto import EncryptResult, SecureInvokeCrypto, get_default_crypto
from .errors import (
    ConfigError,
    CryptoError,
    KMSError,
    SecureInvokeError,
    TransportError,
)
from .keys import PublicKey
from .kms import KMSClient
from .native import NativeInvokeBackend, resolve_native_bin

__all__ = [
    "__version__",
    "SecureInvokeClient",
    "SecureInvokeConfig",
    "SecureInvokeCrypto",
    "EncryptResult",
    "get_default_crypto",
    "NativeInvokeBackend",
    "resolve_native_bin",
    "KMSClient",
    "PublicKey",
    "KeyCache",
    "MemoryKeyCache",
    "FileKeyCache",
    "SecureInvokeError",
    "ConfigError",
    "CryptoError",
    "KMSError",
    "TransportError",
    "DEFAULT_KMS_KEYS_ENDPOINT",
    "DEFAULT_OFFER_ENDPOINT",
    "DEFAULT_CACHE_TTL_SECONDS",
    "DEFAULT_TARGET_SERVICE",
]
