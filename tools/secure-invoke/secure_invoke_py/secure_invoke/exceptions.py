"""
Custom exceptions for Secure Invoke library
"""


class SecureInvokeError(Exception):
    """Base exception for all Secure Invoke errors"""
    pass


class CryptoError(SecureInvokeError):
    """Raised when cryptographic operations fail"""
    pass


class KMSError(SecureInvokeError):
    """Raised when KMS operations fail"""
    pass


class RequestError(SecureInvokeError):
    """Raised when HTTP requests fail"""
    pass


class ConfigurationError(SecureInvokeError):
    """Raised when configuration is invalid"""
    pass


class ValidationError(SecureInvokeError):
    """Raised when request/response validation fails"""
    pass


class RetryError(SecureInvokeError):
    """Raised when all retry attempts are exhausted"""
    pass
