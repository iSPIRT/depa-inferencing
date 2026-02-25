"""
Pytest configuration and fixtures for key-value service tests.
"""
import logging
import os
import sys
from pathlib import Path

import pytest

# Allow importing delta_tooling and csv_generator from parent (tools/key-value-service)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from .kv_client import build_getvalues_body

# Show delta generation/upload logs during tests (use pytest --log-cli-level=INFO to see)
logging.getLogger("delta_tooling").setLevel(logging.INFO)
logging.getLogger("tests.test_getvalues").setLevel(logging.INFO)
logging.getLogger("tests.test_getvalues_incremental").setLevel(logging.INFO)


def pytest_addoption(parser):
    parser.addoption(
        "--kv-url",
        action="store",
        default=os.environ.get("KV_BASE_URL", "http://localhost:51052"),
        help="Key-value service base URL (e.g. http://IP:51052)",
    )
    parser.addoption(
        "--kv-hostname",
        action="store",
        default=os.environ.get("KV_TEST_HOSTNAME", "test.com"),
        help="Hostname to use in getValues metadata",
    )


@pytest.fixture(scope="session")
def kv_base_url(request):
    return request.config.getoption("--kv-url", default="http://localhost:51052").rstrip("/")


@pytest.fixture(scope="session")
def kv_hostname(request):
    return request.config.getoption("--kv-hostname", default="test.com").rstrip("/")


@pytest.fixture
def getvalues_body(kv_hostname):
    """Default getValues body with keys 0, 1 (matches first-delta test key_start=0, num_records=2)."""
    return build_getvalues_body(kv_hostname, ["0", "1"])
