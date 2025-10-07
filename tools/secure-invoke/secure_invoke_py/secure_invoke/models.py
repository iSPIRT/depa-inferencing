"""
Data models and configuration classes for Secure Invoke
"""

from typing import Optional, Dict, Any, List
from pathlib import Path
from pydantic import BaseModel, Field, field_validator, ConfigDict
from datetime import datetime


class SecureInvokeConfig(BaseModel):
    """Configuration for Secure Invoke client"""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    # Required parameters
    kms_host: str = Field(..., description="Host and port of the KMS service")
    buyer_host: str = Field(..., description="The Bank's API Gateway host and endpoint")
    target_service: str = Field(default="bfe", description="Target backend service (bfe or sfe)")
    
    # Authentication
    headers: Dict[str, str] = Field(default_factory=dict, description="HTTP headers including credentials")
    client_cert: Optional[Path] = Field(default=None, description="Path to client certificate file")
    client_key: Optional[Path] = Field(default=None, description="Path to client private key file")
    ca_cert: Optional[Path] = Field(default=None, description="Path to CA certificate")
    
    # Network settings
    insecure: bool = Field(default=False, description="Disable certificate validation (dev only)")
    retries: int = Field(default=3, ge=0, description="Number of retry attempts on network failure")
    timeout: int = Field(default=120, gt=0, description="Request timeout in seconds")
    
    # Batch processing
    max_concurrent_requests: int = Field(default=10, ge=1, description="Max concurrent requests for batch mode")
    retry_delay_ms: int = Field(default=500, ge=0, description="Delay in milliseconds between retries")
    
    # Debug and feature flags (matching C++ implementation)
    enable_verbose: bool = Field(default=False, description="Enable verbose logging")
    enable_debug_reporting: Optional[bool] = Field(default=None, description="Enable debug reporting in requests")
    enable_debug_info: Optional[bool] = Field(default=None, description="Enable debug info in requests")
    enable_unlimited_egress: Optional[bool] = Field(default=None, description="Enable unlimited egress")
    enforce_kanon: Optional[bool] = Field(default=None, description="Enforce k-anonymity check")
    
    # Client metadata
    client_ip: str = Field(default="127.0.0.1", description="Client IP address")
    client_user_agent: str = Field(
        default="SecureInvokePython/1.0.0",
        description="User agent string"
    )
    client_accept_language: str = Field(default="en-US,en;q=0.9", description="Accept language")
    
    @field_validator('client_cert', 'client_key', 'ca_cert')
    @classmethod
    def validate_cert_path(cls, v: Optional[Path]) -> Optional[Path]:
        """Validate certificate paths exist and canonicalize them"""
        if v is not None:
            # Canonicalize path to prevent path traversal
            v = v.resolve()
            if not v.exists():
                raise ValueError(f"Certificate file not found: {v}")
            if not v.is_file():
                raise ValueError(f"Path is not a file: {v}")
        return v
    
    @field_validator('kms_host', 'buyer_host')
    @classmethod
    def validate_host(cls, v: str) -> str:
        """Validate host is not empty"""
        if not v or not v.strip():
            raise ValueError("Host cannot be empty")
        return v.strip()
    
    def validate_mtls(self) -> None:
        """Validate mTLS configuration"""
        if (self.client_cert is None) != (self.client_key is None):
            raise ValueError("Both client_cert and client_key must be provided or neither")


class InterestGroup(BaseModel):
    """Interest group in a GetBids request"""
    
    name: str
    bidding_signals_keys: List[str] = Field(default_factory=list, alias="biddingSignalsKeys")
    user_bidding_signals: Optional[str] = Field(default=None, alias="userBiddingSignals")
    
    model_config = ConfigDict(populate_by_name=True)


class BuyerInput(BaseModel):
    """Buyer input for GetBids request"""
    
    interest_groups: List[InterestGroup] = Field(default_factory=list, alias="interestGroups")
    
    model_config = ConfigDict(populate_by_name=True)


class GetBidsRequest(BaseModel):
    """GetBids request model"""
    
    buyer_input: BuyerInput = Field(alias="buyerInput")
    publisher_name: str = Field(alias="publisherName")
    seller: Optional[str] = None
    client_type: Optional[str] = Field(default=None, alias="clientType")
    auction_signals: Optional[str] = Field(default="{}", alias="auctionSignals")
    buyer_signals: Optional[str] = Field(default="{}", alias="buyerSignals")
    
    model_config = ConfigDict(populate_by_name=True)
    
    def to_proto_dict(self) -> Dict[str, Any]:
        """Convert to dictionary suitable for protobuf"""
        return self.model_dump(by_alias=True, exclude_none=True)


class GetBidsResponse(BaseModel):
    """GetBids response model"""
    
    bids: List[Dict[str, Any]] = Field(default_factory=list)
    debug_info: Optional[Dict[str, Any]] = None
    
    @classmethod
    def from_proto_dict(cls, data: Dict[str, Any]) -> "GetBidsResponse":
        """Create from protobuf dictionary"""
        return cls(**data)


class BatchRequestEntry(BaseModel):
    """Single entry in a batch request file"""
    
    id: int
    request: Dict[str, Any]


class BatchResultEntry(BaseModel):
    """Result of processing a single batch request"""
    
    id: int
    attempts: int
    success: bool
    response: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class BatchResult(BaseModel):
    """Overall result of batch processing"""
    
    total: int
    successful: int
    failed: int
    results: List[BatchResultEntry]
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate"""
        return (self.successful / self.total * 100) if self.total > 0 else 0.0


class KMSKey(BaseModel):
    """KMS public key information"""
    
    key: str = Field(..., description="Base64-encoded public key")
    id: str = Field(..., description="Key ID")
    
    def to_bytes(self) -> bytes:
        """Convert key to bytes"""
        import base64
        return base64.b64decode(self.key)
