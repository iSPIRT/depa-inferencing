"""
Cryptographic operations for Secure Invoke using HPKE and AEAD
"""

import logging
import base64
import gzip
import struct
from typing import Tuple, Dict, Any
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
import pyhpke

from .exceptions import CryptoError
from .models import KMSKey

logger = logging.getLogger(__name__)


class CryptoClient:
    """Handles all cryptographic operations for secure invoke"""
    
    # HPKE suite configuration
    HPKE_KEM_ID = pyhpke.KEMId.DHKEM_X25519_HKDF_SHA256  # 0x0020
    HPKE_KDF_ID = pyhpke.KDFId.HKDF_SHA256  # 0x0001
    HPKE_AEAD_ID = pyhpke.AEADId.AES256_GCM  # 0x0002
    
    def __init__(self):
        """Initialize crypto client"""
        logger.debug("Initialized crypto client")
    
    def encrypt_request(
        self,
        plaintext: bytes,
        public_key: KMSKey
    ) -> Tuple[bytes, bytes]:
        """
        Encrypt request using HPKE
        
        Args:
            plaintext: Raw request data to encrypt
            public_key: KMS public key
            
        Returns:
            Tuple of (encrypted_payload, encryption_context_secret)
            
        Raises:
            CryptoError: If encryption fails
        """
        try:
            logger.debug(f"Encrypting request of size {len(plaintext)} bytes")
            
            # Decode public key
            pk_bytes = public_key.to_bytes()
            
            # Create HPKE suite
            suite = pyhpke.CipherSuite.new(
                self.HPKE_KEM_ID,
                self.HPKE_KDF_ID,
                self.HPKE_AEAD_ID
            )
            
            # Deserialize public key for HPKE
            pk_obj = suite.kem.deserialize_public_key(pk_bytes)
            
            # Setup sender (encrypt)
            info = b""  # Empty info as per B&A protocol
            enc, sender_context = suite.create_sender_context(pk_obj, info)
            
            # Encrypt the plaintext
            aad = b""  # Empty AAD as per B&A protocol
            ciphertext = sender_context.seal(plaintext, aad)
            
            # The encrypted payload includes the encapsulated key + ciphertext
            encrypted_payload = enc + ciphertext
            
            # Generate secret for response decryption (using HKDF)
            secret = self._derive_response_secret(sender_context)
            
            logger.debug(f"Successfully encrypted request, output size: {len(encrypted_payload)} bytes")
            
            return encrypted_payload, secret
            
        except Exception as e:
            raise CryptoError(f"Failed to encrypt request: {str(e)}") from e
    
    def decrypt_response(
        self,
        ciphertext: bytes,
        secret: bytes
    ) -> bytes:
        """
        Decrypt response using AEAD with the secret from request encryption
        
        Args:
            ciphertext: Encrypted response data (format: nonce + encrypted_data + auth_tag)
            secret: Secret from request encryption
            
        Returns:
            Decrypted plaintext
            
        Raises:
            CryptoError: If decryption fails
        """
        try:
            logger.debug(f"Decrypting response of size {len(ciphertext)} bytes")
            
            # Validate minimum ciphertext length
            # GCM standard: 12 bytes nonce + at least 16 bytes for tag
            if len(ciphertext) < 28:  # 12 (nonce) + 16 (min tag)
                raise CryptoError(f"Ciphertext too short: {len(ciphertext)} bytes")
            
            # Derive AEAD key from secret
            # The secret from HPKE export is 32 bytes, use all 32 for AES-256-GCM
            if len(secret) < 32:
                raise CryptoError(f"Secret too short: {len(secret)} bytes, need at least 32")
            
            key = secret[:32]  # AES-256-GCM uses 256-bit (32-byte) key
            
            # Standard AEAD format: nonce (12 bytes) || ciphertext || tag (16 bytes)
            # The tag is appended to the ciphertext by the AEAD algorithm
            nonce = ciphertext[:12]
            encrypted_data_with_tag = ciphertext[12:]
            
            # Decrypt using AES-GCM
            # The decrypt method expects: nonce, ciphertext+tag, optional AAD
            aesgcm = AESGCM(key)
            plaintext = aesgcm.decrypt(
                nonce=nonce,
                data=encrypted_data_with_tag,  # This includes the auth tag
                associated_data=None  # No AAD used in this protocol
            )
            
            logger.debug(f"Successfully decrypted response, output size: {len(plaintext)} bytes")
            
            return plaintext
            
        except CryptoError:
            raise
        except Exception as e:
            raise CryptoError(f"AEAD decryption failed: {str(e)}") from e
    
    def compress_payload(self, data: bytes) -> bytes:
        """
        Compress data using gzip
        
        Args:
            data: Data to compress
            
        Returns:
            Compressed data
        """
        try:
            compressed = gzip.compress(data)
            logger.debug(f"Compressed {len(data)} bytes to {len(compressed)} bytes")
            return compressed
        except Exception as e:
            raise CryptoError(f"Failed to compress data: {str(e)}") from e
    
    def decompress_payload(self, data: bytes) -> bytes:
        """
        Decompress gzip data
        
        Args:
            data: Compressed data
            
        Returns:
            Decompressed data
        """
        try:
            decompressed = gzip.decompress(data)
            logger.debug(f"Decompressed {len(data)} bytes to {len(decompressed)} bytes")
            return decompressed
        except Exception as e:
            raise CryptoError(f"Failed to decompress data: {str(e)}") from e
    
    def _derive_response_secret(self, sender_context) -> bytes:
        """
        Derive secret for response decryption from HPKE context
        
        This matches the C++ implementation's secret generation
        """
        # Export secret from HPKE context
        exporter_context = b"response_secret"
        secret = sender_context.export(exporter_context, 32)  # Export 32 bytes
        return secret
    
    def _derive_aead_key(self, secret: bytes) -> bytes:
        """
        Derive AEAD key from secret using HKDF
        
        Args:
            secret: Input secret material
            
        Returns:
            Derived key (32 bytes for AES-256-GCM)
        """
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=None,
            info=b"aead_key"
        )
        return hkdf.derive(secret)


def encode_response_payload(data: bytes, compress: bool = True) -> bytes:
    """
    Encode and optionally compress payload following B&A format
    
    Args:
        data: Raw data
        compress: Whether to compress
        
    Returns:
        Encoded payload with framing
    """
    if compress:
        crypto = CryptoClient()
        data = crypto.compress_payload(data)
    
    # Add framing: 4-byte length prefix (big-endian)
    length = struct.pack('>I', len(data))
    return length + data


def decode_request_payload(data: bytes, decompress: bool = True) -> bytes:
    """
    Decode and optionally decompress payload following B&A format
    
    Args:
        data: Encoded data with framing
        decompress: Whether to decompress
        
    Returns:
        Raw decoded data
    """
    # Remove framing: 4-byte length prefix
    if len(data) < 4:
        raise CryptoError("Invalid payload: too short")
    
    length = struct.unpack('>I', data[:4])[0]
    payload = data[4:]
    
    if len(payload) != length:
        logger.warning(f"Payload length mismatch: expected {length}, got {len(payload)}")
    
    if decompress:
        crypto = CryptoClient()
        payload = crypto.decompress_payload(payload)
    
    return payload
