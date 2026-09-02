"""Transports that carry an encrypted GetBids request to the offer host."""

from .base import Transport
from .rest import RestTransport
from .grpc_ import GrpcTransport

__all__ = ["Transport", "RestTransport", "GrpcTransport", "build_transport"]


def build_transport(config):
    """Create the transport matching ``config.protocol``."""
    if config.protocol == "grpc":
        return GrpcTransport(config)
    return RestTransport(config)
