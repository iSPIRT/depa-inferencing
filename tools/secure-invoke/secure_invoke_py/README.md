# Secure Invoke Python Library

A Python implementation of the Secure Invoke tool for making encrypted requests to the Bank's API Gateway with HPKE encryption and mTLS support.

## Features

- 🔐 **HPKE Encryption**: Hybrid Public Key Encryption for request/response security
- 🔒 **mTLS Support**: Mutual TLS authentication with client certificates
- 🚀 **High Performance**: Connection pooling and persistent sessions
- 📦 **Batch Processing**: Process multiple requests concurrently
- 🔄 **Automatic Retries**: Built-in retry logic with exponential backoff
- 🎯 **Type-Safe**: Full type hints and Pydantic models
- 📚 **Dual Interface**: Both programmatic API and CLI tool

## Installation

### From source

```bash
cd secure_invoke_py
pip install -e .
```

### From package

```bash
pip install secure-invoke
```

## Quick Start

### Programmatic Usage

```python
from pathlib import Path
from secure_invoke import SecureInvokeClient, SecureInvokeConfig

# Configure client
config = SecureInvokeConfig(
    kms_host="depa-inferencing-kms.centralindia.cloudapp.azure.com",
    buyer_host="api.hdfcbank.com/api/v1/getbids",
    target_service="bfe",
    headers={
        "Api-Key": "YOUR_API_KEY",
        "Authorization": "Bearer YOUR_TOKEN",
        "SCOPE": "YOUR_SCOPE"
    },
    client_cert=Path("client.crt"),
    client_key=Path("client.key")
)

# Create client
with SecureInvokeClient(config) as client:
    # Make a request
    request = {
        "client_type": "CLIENT_TYPE_BROWSER",
        "buyerInput": {
            "interestGroups": [{
                "name": "Rajini Kausalya",
                "biddingSignalsKeys": ["9999999990"],
                "userBiddingSignals": '{"age":58, "average_amount_spent":50008000}'
            }]
        },
        "seller": "ergo.com",
        "publisherName": "ergo.com"
    }
    
    response = client.get_bids(request)
    print(response)
```

### Batch Processing

```python
from secure_invoke import BatchProcessor

# Process batch file
with BatchProcessor(config) as processor:
    result = processor.process_batch_file(
        batch_file=Path("batch_requests.jsonl"),
        output_dir=Path("output")
    )
    
    print(f"Success rate: {result.success_rate:.1f}%")
```

## CLI Usage

### Single Request

```bash
secure-invoke invoke \
    --kms-host depa-inferencing-kms.centralindia.cloudapp.azure.com \
    --buyer-host api.hdfcbank.com/api/v1/getbids \
    --request-path request.json \
    --headers '{"Api-Key": "YOUR_KEY", "Authorization": "Bearer TOKEN"}' \
    --client-cert client.crt \
    --client-key client.key
```

### Batch Processing

```bash
secure-invoke batch \
    --kms-host depa-inferencing-kms.centralindia.cloudapp.azure.com \
    --buyer-host api.hdfcbank.com/api/v1/getbids \
    --batch-file batch_requests.jsonl \
    --headers '{"Api-Key": "YOUR_KEY", "Authorization": "Bearer TOKEN"}' \
    --client-cert client.crt \
    --client-key client.key \
    --max-concurrent 10
```

### Test KMS Connectivity

```bash
secure-invoke test-kms \
    --kms-host depa-inferencing-kms.centralindia.cloudapp.azure.com
```

## Request Format

### Single Request (JSON)

```json
{
  "client_type": "CLIENT_TYPE_BROWSER",
  "buyerInput": {
    "interestGroups": [
      {
        "name": "Rajini Kausalya",
        "biddingSignalsKeys": ["9999999990"],
        "userBiddingSignals": "{\"age\":58, \"average_amount_spent\":50008000}"
      }
    ]
  },
  "seller": "ergo.com",
  "publisherName": "ergo.com"
}
```

### Batch Request (JSONL)

Each line is a JSON object:

```jsonl
{"id":1,"request":{"client_type":"CLIENT_TYPE_BROWSER","buyerInput":{"interestGroups":[{"biddingSignalsKeys":["9999999990"],"name":"Rajni Kausalya","userBiddingSignals":"{\"age\":29, \"average_amount_spent\":10000, \"total_spent\":20000}"}]},"seller":"irctc.com","publisherName":"irctc.com"}}
{"id":2,"request":{"client_type":"CLIENT_TYPE_BROWSER","buyerInput":{"interestGroups":[{"biddingSignalsKeys":["9999999991"],"name":"Sumitra Rao","userBiddingSignals":"{\"age\":42}"}]},"seller":"irctc.com","publisherName":"irctc.com"}}
```

## Configuration Parameters

All parameters from the Docker-based onboarding are supported:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `kms_host` | Yes | KMS service host for key fetching |
| `buyer_host` | Yes | Bank's API Gateway endpoint |
| `target_service` | Yes | Target service (default: bfe) |
| `headers` | Yes | HTTP headers (API Key, Authorization, etc.) |
| `client_cert` | Yes* | Path to client certificate |
| `client_key` | Yes* | Path to client private key |
| `ca_cert` | No | Path to CA certificate |
| `insecure` | No | Disable cert validation (dev only) |
| `retries` | No | Number of retry attempts (default: 3) |
| `max_concurrent_requests` | No | Max concurrent requests (default: 10) |
| `enable_verbose` | No | Enable verbose logging |

\* Required for production mTLS

## Architecture

```
┌─────────────────────────────────────────┐
│         Secure Invoke Client            │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────────┐ │
│  │ KMS Fetcher  │  │  Crypto Client  │ │
│  │ (Key Cache)  │  │  (HPKE/AEAD)    │ │
│  └──────────────┘  └─────────────────┘ │
│  ┌─────────────────────────────────────┤
│  │     HTTP Session (Connection Pool)  │
│  │     mTLS, Retry Logic, Timeouts     │
│  └─────────────────────────────────────┘
└─────────────────────────────────────────┘
```

## Advantages over Docker Implementation

- ⚡ **10-100x faster**: No container startup overhead
- 🔑 **Key caching**: Fetch keys once, reuse across requests
- 🔌 **Connection pooling**: Persistent HTTPS connections
- 💻 **Programmatic API**: Direct function calls, no file I/O
- 🧪 **Easier testing**: Unit tests without Docker
- 📦 **Lightweight**: No container runtime required

## Development

### Setup development environment

```bash
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
pip install -e .
```

### Run tests

```bash
pytest tests/ -v
```

### Code formatting

```bash
black secure_invoke/
mypy secure_invoke/
```

## Security Considerations

- **Never use `insecure=True` in production**
- **Protect your client certificates and private keys**
- **Rotate OAuth tokens regularly** (900s expiry)
- **Use CA certificates for production**
- **Enable verbose logging only for debugging**

## Migration from Docker

The Python library maintains full compatibility with the Docker implementation:

```python
# Old Docker command:
# podman run --rm -v ./requests:/requests \
#   -e KMS_HOST=... -e BUYER_HOST=... \
#   -e REQUEST_PATH=requests/request.json \
#   ispirt.azurecr.io/depa-inferencing/tools/secure_invoke:4.8.0.2

# New Python equivalent:
from secure_invoke import SecureInvokeClient, SecureInvokeConfig
import json

config = SecureInvokeConfig(kms_host="...", buyer_host="...")
with SecureInvokeClient(config) as client:
    with open("requests/request.json") as f:
        request = json.load(f)
    response = client.get_bids(request)
```

## License

Apache License 2.0

## Support

For issues and questions, please contact the DEPA team.
