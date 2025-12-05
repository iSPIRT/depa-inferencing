"""
Serdes utilities for BYOB Python tools.

This package provides serialization and deserialization functionality for protobuf messages,
making it easier to work with protobuf in the BYOB Python environment.
"""

__version__ = '0.1.0'

# Import the main functionality to make it available at the package level
from .serdes import read_request_from_fd, write_response_to_fd, gen_protobuf_payload