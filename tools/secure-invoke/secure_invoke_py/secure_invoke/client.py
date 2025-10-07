"""
Main Secure Invoke client for making encrypted requests to the Bank's API
"""

import logging
import json
import base64
from typing import Dict, Any, Optional
from pathlib import Path

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .models import SecureInvokeConfig, GetBidsRequest, GetBidsResponse, KMSKey
from .kms import KMSKeyFetcher
from .crypto import CryptoClient
from .exceptions import RequestError, CryptoError, ValidationError

logger = logging.getLogger(__name__)


class SecureInvokeClient:
    """
    Secure Invoke client for making encrypted requests to the Bank's API Gateway
    
    This client handles:
    - Fetching public keys from KMS
    - Encrypting requests with HPKE
    - Sending HTTPS requests with mTLS
    - Decrypting responses
    - Connection pooling and retry logic
    """
    
    def __init__(self, config: SecureInvokeConfig):
        """
        Initialize Secure Invoke client
        
        Args:
            config: Client configuration
            
        Raises:
            ConfigurationError: If configuration is invalid
        """
        self.config = config
        self.config.validate_mtls()
        
        # Initialize components
        self.kms = KMSKeyFetcher(
            kms_host=config.kms_host,
            insecure=config.insecure,
            timeout=config.timeout
        )
        self.crypto = CryptoClient()
        
        # Setup HTTP session with connection pooling
        self.session = self._create_session()
        
        # Cache the KMS key
        self._cached_key: Optional[KMSKey] = None
        
        logger.info(f"Initialized SecureInvokeClient for {config.buyer_host}")
    
    def _create_session(self) -> requests.Session:
        """Create HTTP session with retry logic and connection pooling"""
        session = requests.Session()
        
        # Setup retry strategy
        retry_strategy = Retry(
            total=self.config.retries,
            backoff_factor=self.config.retry_delay_ms / 1000.0,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["POST", "GET"]
        )
        
        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=self.config.max_concurrent_requests,
            pool_maxsize=self.config.max_concurrent_requests * 2
        )
        
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        return session
    
    def get_bids(
        self,
        request: Dict[str, Any],
        refresh_key: bool = False
    ) -> Dict[str, Any]:
        """
        Make a GetBids request to the Bank's API
        
        Args:
            request: GetBids request as dictionary (following the onboarding format)
            refresh_key: Force refresh KMS key
            
        Returns:
            Decrypted response as dictionary
            
        Raises:
            RequestError: If request fails
            CryptoError: If encryption/decryption fails
            ValidationError: If request/response validation fails
        """
        try:
            # Validate and convert request
            validated_request = self._validate_request(request)
            
            # Get public key from KMS
            if refresh_key or self._cached_key is None:
                self._cached_key = self.kms.fetch_key(force_refresh=refresh_key)
            
            # Serialize request to protobuf format
            request_bytes = self._serialize_request(validated_request)
            
            # Encrypt request
            encrypted_request, secret = self.crypto.encrypt_request(
                request_bytes,
                self._cached_key
            )
            
            # Prepare JSON payload for HTTP request
            json_payload = self._prepare_json_payload(encrypted_request, self._cached_key)
            
            # Send HTTPS request
            response_data = self._send_request(json_payload)
            
            # Decrypt and parse response
            decrypted_response = self._decrypt_response(response_data, secret)
            
            return decrypted_response
            
        except Exception as e:
            logger.error(f"Failed to process GetBids request: {str(e)}")
            raise
    
    def _validate_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate request format
        
        Args:
            request: Request dictionary
            
        Returns:
            Validated request
            
        Raises:
            ValidationError: If request is invalid
        """
        try:
            # Check required fields based on onboarding doc
            if "buyerInput" not in request:
                raise ValidationError("Request must contain 'buyerInput' field")
            
            if "publisherName" not in request:
                raise ValidationError("Request must contain 'publisherName' field")
            
            buyer_input = request.get("buyerInput", {})
            if "interestGroups" not in buyer_input:
                raise ValidationError("buyerInput must contain 'interestGroups' field")
            
            # client_type is optional, but if present, normalize to snake_case for consistency
            if "clientType" in request:
                request["client_type"] = request.pop("clientType")
            
            return request
            
        except Exception as e:
            raise ValidationError(f"Invalid request format: {str(e)}") from e
    
    def _serialize_request(self, request: Dict[str, Any]) -> bytes:
        """
        Serialize request to protobuf bytes
        
        For now, we use JSON serialization. In production, this should use
        actual protobuf serialization with the generated proto files.
        
        Args:
            request: Request dictionary
            
        Returns:
            Serialized bytes
        """
        # Convert to JSON and then to bytes
        # TODO: Replace with actual protobuf serialization when proto files are available
        json_str = json.dumps(request)
        return json_str.encode('utf-8')
    
    def _prepare_json_payload(
        self,
        encrypted_request: bytes,
        key: KMSKey
    ) -> Dict[str, Any]:
        """
        Prepare JSON payload for HTTP request
        
        Args:
            encrypted_request: Encrypted request bytes
            key: KMS key used for encryption
            
        Returns:
            JSON payload dictionary
        """
        # Base64 encode the encrypted request
        encrypted_b64 = base64.b64encode(encrypted_request).decode('ascii')
        
        # Prepare payload following B&A format
        payload = {
            "request_ciphertext": encrypted_b64,
            "key_id": key.id,
            "version": "1.0"
        }
        
        return payload
    
    def _send_request(self, json_payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send HTTPS request to the Bank's API
        
        Args:
            json_payload: JSON payload to send
            
        Returns:
            Response JSON
            
        Raises:
            RequestError: If request fails
        """
        try:
            # Prepare URL
            url = self.config.buyer_host
            if not url.startswith(('http://', 'https://')):
                url = f"https://{url}"
            
            # Prepare headers
            headers = {
                "Content-Type": "application/json",
                "x-bna-client-ip": self.config.client_ip,
                "x-user-agent": self.config.client_user_agent,
                "x-accept-language": self.config.client_accept_language,
            }
            
            # Add custom headers from config (API Key, Authorization, etc.)
            headers.update(self.config.headers)
            
            # Prepare mTLS certificates
            cert = None
            if self.config.client_cert and self.config.client_key:
                cert = (str(self.config.client_cert), str(self.config.client_key))
            
            # Prepare CA cert
            verify: Any = not self.config.insecure
            if self.config.ca_cert:
                verify = str(self.config.ca_cert)
            
            if self.config.enable_verbose:
                logger.info(f"Sending request to {url}")
                logger.debug(f"Headers: {headers}")
                logger.debug(f"Payload keys: {list(json_payload.keys())}")
            
            # Send request
            response = self.session.post(
                url,
                json=json_payload,
                headers=headers,
                cert=cert,
                verify=verify,
                timeout=self.config.timeout
            )
            
            response.raise_for_status()
            
            if self.config.enable_verbose:
                logger.info(f"Received response with status {response.status_code}")
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            raise RequestError(f"HTTP request failed: {str(e)}") from e
        except json.JSONDecodeError as e:
            raise RequestError(f"Invalid JSON response: {str(e)}") from e
    
    def _decrypt_response(
        self,
        response_data: Dict[str, Any],
        secret: bytes
    ) -> Dict[str, Any]:
        """
        Decrypt and parse response
        
        Args:
            response_data: Response JSON from server
            secret: Secret from request encryption
            
        Returns:
            Decrypted response dictionary
            
        Raises:
            CryptoError: If decryption fails
        """
        try:
            # Extract response ciphertext
            if "response_ciphertext" not in response_data and "responseCiphertext" not in response_data:
                raise CryptoError("Response missing ciphertext field")
            
            response_ciphertext_b64 = response_data.get(
                "response_ciphertext",
                response_data.get("responseCiphertext")
            )
            
            # Decode base64
            response_ciphertext = base64.b64decode(response_ciphertext_b64)
            
            # Decrypt
            decrypted_bytes = self.crypto.decrypt_response(response_ciphertext, secret)
            
            # Parse JSON (or protobuf in production)
            # TODO: Replace with protobuf parsing when proto files are available
            decrypted_json = json.loads(decrypted_bytes.decode('utf-8'))
            
            if self.config.enable_verbose:
                logger.debug(f"Decrypted response: {decrypted_json}")
            
            return decrypted_json
            
        except Exception as e:
            raise CryptoError(f"Failed to decrypt response: {str(e)}") from e
    
    def close(self) -> None:
        """Close the HTTP session"""
        self.session.close()
        logger.info("Closed SecureInvokeClient session")
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()
