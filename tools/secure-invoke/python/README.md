# Secure Invoke — Python SDK Docker Image

Docker packaging for the [`secure_request`](https://github.com/saranggalada/bidding-auction-servers/releases/download/v0.1.0/secure_request-0.1.0-py3-none-any.whl) Python SDK. Use this when your environment requires running secure invoke from a container instead of installing Python dependencies on the host.

The container accepts the **same environment variables** as the legacy C++ `secure_invoke` image under `../docker-compose.yml`, except retries use `RUN_RETRIES` (full end-to-end) instead of `RETRIES`.

**Published image:** `ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1`

## Client Quickstart

### 1. Prerequisites

- Docker installed on the client machine
- Network access to KMS, Offer Frontend (OFE), and ACR
- Azure CLI (`az`) with permission to pull from `ispirt` ACR

### 2. Authenticate and pull

```bash
docker pull ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
```

### 3. Request file

Use the sample request bundled in this repo at [`tools/requests/get_bids_request.json`](../../requests/get_bids_request.json). From the repo root:

```bash
ls tools/requests/get_bids_request.json
```

To use your own payload, add a JSON file under `tools/requests/` (or any host directory you mount as `/requests`).

### 4. Run inference request

From the **repo root**, replace `OFE_IP` with the Offer Frontend load balancer IP (`kubectl get svc ofe-lb -n default`).

```bash
export OFE_IP=<OFE_IP>

docker run --rm --network host \
  -v "${PWD}/tools/requests:/requests" \
  -e KMS_HOST=https://depa-inferencing-kms-uat-azure.ispirt.in \
  -e BUYER_HOST="${OFE_IP}:51052/v1/getbids" \
  -e REQUEST_PATH=/requests/get_bids_request.json \
  -e OPERATION=rest_invoke \
  -e INSECURE=true \
  -e RUN_RETRIES=3 \
  -e KMS_KEYS_ENDPOINT=/app/listpubkeys \
  ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
```
The above command is for UAT. For prod, use `KMS_HOST=https://depa-inferencing-kms-azure.ispirt.in` and the prod OFE IP. Note, prod KMS is only compatible with prod CCR services.

A successful run prints decrypted JSON to stdout (an empty `updateInterestGroupList` is normal for the sample request).

### 5. Optional: docker compose

From a checkout of this repo:

```bash
cd tools/secure-invoke/python
cp .env.example .env   # set HOST_REQUESTS_DIR to repo tools/requests, plus KMS_HOST, BUYER_HOST, OFE IP
export SECURE_INVOKE_PYTHON_IMAGE=ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
./secure_invoke_test.sh
```

In `.env`, set `HOST_REQUESTS_DIR` to the absolute path of `tools/requests` in your checkout, e.g. `"${PWD}/../../requests"` when your shell is in `tools/secure-invoke/python`.

## Quick start (build from source)

### 1. Build the image

```bash
cd tools/secure-invoke/python
./build.sh ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
```

### 2. Configure environment

```bash
cp .env.example .env
```

Set `HOST_REQUESTS_DIR` to your checkout’s `tools/requests` directory (see `.env.example`).

### 3. Run

```bash
./secure_invoke_test.sh
```

## Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KMS_HOST` | KMS base URL | required |
| `BUYER_HOST` | Offer Frontend HTTP URL (`host:port/path`; `http://` added if omitted) | required |
| `REQUEST_PATH` | Request file path inside container | `/requests/get_bids_request.json` |
| `OPERATION` | `rest_invoke`, `encrypt`, or `batch_invoke` | `rest_invoke` |
| `RUN_RETRIES` | Full end-to-end retries (KMS + encrypt + HTTP + decrypt) | `3` |
| `RUN_RETRY_DELAY` | Seconds between run retries | `5` |
| `INSECURE` | Skip TLS verification (`true`/`false`) | `true` |
| `HEADERS` | Extra HTTP headers as JSON | — |
| `CLIENT_KEY` | Client key filename under certs mount | — |
| `CLIENT_CERT` | Client cert filename under certs mount | — |
| `CA_CERT` | CA cert filename under certs mount | — |
| `ENABLE_VERBOSE` | Verbose SDK output | `false` |
| `MAX_CONCURRENT_REQUESTS` | Batch parallelism | `2` |
| `KMS_KEYS_ENDPOINT` | KMS list-keys path | `/listpubkeys` |
| `SECURE_REQUEST_USER_AGENT` | User-Agent for KMS calls | `depa-secure-invoke-python/0.1.0` |

## Layout

```
python/
├── Dockerfile
├── invoke.py
├── entrypoint.sh
├── docker-compose.yml
├── secure_invoke_test.sh
├── build.sh
├── .env.example
└── README.md
```
