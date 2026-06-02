# Secure Invoke — Python SDK Docker Image

Docker packaging for the [`secure_request`](https://github.com/saranggalada/bidding-auction-servers/releases/download/v0.1.0/secure_request-0.1.0-py3-none-any.whl) Python SDK. Use this when your environment requires running secure invoke from a container instead of installing Python dependencies on the host.

The container accepts the **same environment variables** as the legacy C++ `secure_invoke` image under `../docker-compose.yml`, except retries use `RUN_RETRIES` (full end-to-end) instead of `RETRIES`.

**Published image:** `ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1`

## Client runbook

### 1. Prerequisites

- Docker installed on the client machine
- Network access to KMS, Offer Frontend (OFE), and ACR
- Azure CLI (`az`) with permission to pull from `ispirt` ACR

### 2. Authenticate and pull

```bash
docker pull ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
```

### 3. Prepare the request file

Create a directory for request JSON and add your payload, e.g. `get_bids_request.json`:

```bash
mkdir -p ~/secure-invoke-requests
cp get_bids_request.json ~/secure-invoke-requests/
```

### 4. Run (UAT example)

Replace `OFE_IP` with the Offer Frontend load balancer IP (`kubectl get svc ofe-lb -n default`).

```bash
export OFE_IP=4.247.209.150   # example UAT IP

docker run --rm --network host \
  -v ~/secure-invoke-requests:/requests \
  -e KMS_HOST=https://depa-inferencing-kms-uat-azure.ispirt.in \
  -e BUYER_HOST="${OFE_IP}:51052/v1/getbids" \
  -e REQUEST_PATH=/requests/get_bids_request.json \
  -e OPERATION=rest_invoke \
  -e INSECURE=true \
  -e RUN_RETRIES=3 \
  -e KMS_KEYS_ENDPOINT=/app/listpubkeys \
  ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
```

**Prod:** use `KMS_HOST=https://depa-inferencing-kms-azure.ispirt.in` and the prod OFE IP. Note, prod KMS is only compatible with prod CCR services.

A successful run prints decrypted JSON to stdout (an empty `updateInterestGroupList` is normal for the sample request).

### 5. Optional: docker compose

From a checkout of this repo:

```bash
cd tools/secure-invoke/python
cp .env.example .env   # edit HOST_REQUESTS_DIR, KMS_HOST, BUYER_HOST, OFE IP
export SECURE_INVOKE_PYTHON_IMAGE=ispirt.azurecr.io/depainferencing/tools/secure_invoke_python:0.1.1
./secure_invoke_test.sh
```

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

Place your request JSON in the host directory referenced by `HOST_REQUESTS_DIR`.

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

For Azure App Gateway deployments, set `KMS_KEYS_ENDPOINT=/app/listpubkeys`.

## Troubleshooting HTTP 504

If you see **504 Gateway Timeout** from OFE, check the **deployment**, not the client image.

OFE logs will show:

```text
GetBiddingSignals request failed with status: DEADLINE_EXCEEDED
```

**Root cause:** OFE (on AKS virtual nodes) calls KV at `kv.ad_selection.microsoft:51052`. Private DNS for that hostname must resolve to an **internal** VNet address. If the KV service uses a **public** load balancer, virtual-node pods hairpin through the public IP and the KV lookup times out → OFE returns 504.

**Fix (in repo):** `internalLB: true` on the `kv` service in `deployment-scripts/azure/offer-service/services/app/helm/offer.yaml`. Redeploy with Terraform so private DNS updates. After deploy, verify:

```bash
az network private-dns record-set a show \
  -g tf-demo-offer-inc-rg -z ad_selection.microsoft -n kv \
  --query aRecords[0].ipv4Address -o tsv
```

The IP should be a **private** address (like `10.x.x.x`), not a public one.

`RUN_RETRIES` covers brief startup races only; persistent 504s mean the backend routing fix above is required.

## Operations

### `rest_invoke` (default)

Encrypts the request, POSTs to `BUYER_HOST`, decrypts the response, and prints JSON to stdout.

### `encrypt`

Fetches a KMS key and prints the encrypted payload only (no offer-service call).

### `batch_invoke`

Reads a JSONL file from `REQUEST_PATH`. Each line must include an `id` and `request` object. Writes `success_log.jsonl` and `failure_log.jsonl` next to the input file.

## Differences from the C++ image

| Feature | C++ image | Python image |
|---------|-----------|--------------|
| HTTP `rest_invoke` | yes | yes |
| gRPC `invoke` | yes | no — use HTTP `BUYER_HOST` with `/v1/getbids` |
| Retries env | `RETRIES` | `RUN_RETRIES` |
| `encrypt` | yes | yes |
| `batch_invoke` | yes | yes |
| Runtime | native binary | Python 3.10 + `secure_request` wheel |

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
