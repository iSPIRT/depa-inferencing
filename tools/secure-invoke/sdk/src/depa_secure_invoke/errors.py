"""Exception hierarchy for the DEPA secure-invoke SDK."""

from __future__ import annotations


class SecureInvokeError(Exception):
    """Base class for all secure-invoke errors."""


class ConfigError(SecureInvokeError):
    """Invalid or incomplete configuration."""


class CryptoError(SecureInvokeError):
    """Failure inside the C++ crypto library (encrypt/decrypt/init)."""


class KMSError(SecureInvokeError):
    """Failure while fetching public keys from the KMS."""


class TransportError(SecureInvokeError):
    """Failure while sending the request to the offer host (REST or gRPC)."""
