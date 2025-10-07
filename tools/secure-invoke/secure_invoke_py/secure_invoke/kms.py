"""
KMS key fetcher for retrieving public keys from the KMS service
"""

import logging
from typing import Optional, Dict
from datetime import datetime, timedelta
import requests
from urllib.parse import urljoin

from .exceptions import KMSError
from .models import KMSKey

logger = logging.getLogger(__name__)


class KMSKeyFetcher:
    """Fetches and caches public keys from KMS"""
    
    def __init__(
        self,
        kms_host: str,
        cache_ttl_seconds: int = 3600,
        insecure: bool = False,
        timeout: int = 30
    ):
        """
        Initialize KMS key fetcher
        
        Args:
            kms_host: KMS host URL (e.g., "depa-inferencing-kms.centralindia.cloudapp.azure.com")
            cache_ttl_seconds: How long to cache keys before refreshing (default 1 hour)
            insecure: Whether to skip SSL verification (dev only)
            timeout: Request timeout in seconds
        """
        self.kms_host = kms_host.rstrip('/')
        self.cache_ttl = timedelta(seconds=cache_ttl_seconds)
        self.insecure = insecure
        self.timeout = timeout
        
        # Add protocol if not present
        if not self.kms_host.startswith(('http://', 'https://')):
            self.kms_host = f"https://{self.kms_host}"
        
        # Cache
        self._cached_key: Optional[KMSKey] = None
        self._cache_time: Optional[datetime] = None
        
        logger.info(f"Initialized KMS key fetcher for {self.kms_host}")
    
    def fetch_key(self, force_refresh: bool = False) -> KMSKey:
        """
        Fetch public key from KMS, using cache if available
        
        Args:
            force_refresh: Force fetching from KMS even if cache is valid
            
        Returns:
            KMSKey object with public key and ID
            
        Raises:
            KMSError: If fetching fails
        """
        # Check cache
        if not force_refresh and self._is_cache_valid():
            logger.debug("Using cached KMS key")
            return self._cached_key
        
        logger.info(f"Fetching public key from KMS: {self.kms_host}")
        
        try:
            url = urljoin(self.kms_host, "/listpubkeys")
            
            response = requests.get(
                url,
                verify=not self.insecure,
                timeout=self.timeout
            )
            response.raise_for_status()
            
            data = response.json()
            
            if not data or 'keys' not in data or not data['keys']:
                raise KMSError("No keys returned from KMS")
            
            # Get first key
            key_data = data['keys'][0]
            key = KMSKey(key=key_data['key'], id=key_data['id'])
            
            # Update cache
            self._cached_key = key
            self._cache_time = datetime.utcnow()
            
            logger.info(f"Successfully fetched key with ID: {key.id}")
            return key
            
        except requests.exceptions.RequestException as e:
            raise KMSError(f"Failed to fetch key from KMS: {str(e)}") from e
        except (KeyError, IndexError, ValueError) as e:
            raise KMSError(f"Invalid response format from KMS: {str(e)}") from e
    
    def _is_cache_valid(self) -> bool:
        """Check if cached key is still valid"""
        if self._cached_key is None or self._cache_time is None:
            return False
        
        age = datetime.utcnow() - self._cache_time
        return age < self.cache_ttl
    
    def clear_cache(self) -> None:
        """Clear cached key"""
        self._cached_key = None
        self._cache_time = None
        logger.debug("KMS key cache cleared")
