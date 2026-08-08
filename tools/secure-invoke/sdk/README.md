# DEPA Secure Invoke SDK

A single, programmable Python SDK + CLI to encrypt, send and decrypt DEPA
inferencing (Bidding & Auction) **offer requests**, over both:

- **REST** — for Azure offer frontends (an Envoy proxy transcodes JSON to gRPC).
- **gRPC** — for GCP BuyerFrontEnd (BFE), which has no Envoy front door.

It reuses the *exact same* B&A crypto used by the offer services, so payloads
round-trip. Crucially, **Azure and GCP are built from different B&A forks with
different data-plane crypto (OHTTP/HPKE framing)**, so the SDK carries two
backends and picks one automatically:

| Cloud | Protocol | Backend (`--backend`) | Crypto |
|-------|----------|-----------------------|--------|
| Azure | REST     | `python`              | pure-Python ctypes over the vendored `libsecure_invoke.so` + `libcddl.so` (from the Azure fork) |
| GCP   | gRPC     | `native`              | the monolithic `invoke` binary from the GCP fork, driven as a subprocess |

The client always sees one unified `SecureInvokeClient` / `secure-invoke`
interface. `--backend auto` (the default) maps REST→`python` and gRPC→`native`;
override with `--backend python|native`. Key management (`/app/listpubkeys`,
path preservation, caching) always runs in Python.

## Key features

- **Path-preserving hosts** — the endpoint is appended to the *full* KMS/offer
  host, so path-based routes (e.g. `https://gw/tenant-a`) are kept intact.
- **Correct KMS route** — defaults to `/app/listpubkeys`.
- **REST *and* gRPC** in one tool, so Azure and GCP share one SDK.
- **Programmable** — import as a library, send from a file or inline, reuse one
  client (cached key + pooled connection) for thousands of requests, or run
  batches concurrently.
- **Parseable output** — native crypto debug lines are suppressed unless
  `--verbose`, so stdout is always valid JSON.
- **Self-contained binaries** — no `LD_LIBRARY_PATH` needed.

## Install

```bash
./scripts/fetch_libs.sh   # pull the crypto binaries from the registry (see below)
pip install .             # from tools/secure-invoke/sdk
# or build a wheel (bundles whatever binaries are present under src/):
python -m build --wheel
```

> The binaries are Linux x86-64 ELF objects, so the SDK only runs on `linux/amd64`.
> `pip install` succeeds without them, but you must run `fetch_libs.sh` before
> actually invoking (the crypto/native backend loads them lazily and prints a
> clear error if they're missing).

### Crypto binaries (fetched from the registry, not committed)

The crypto binaries are **not** in git (~120 MB total: the Azure
`libsecure_invoke.so` alone is ~72 MB). They are stored as a single **OCI
artifact** in the public iSPIRT container registry and fetched with ORAS:

```bash
# Fetch all crypto binaries into the package tree (Azure .so + GCP native):
./scripts/fetch_libs.sh                          # pinned artifact ref
./scripts/fetch_libs.sh ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk_libs:1.0.0
# or point it via env:
export SECURE_INVOKE_LIBS_REF=<registry>/depainferencing/tools/secure_invoke_sdk_libs:<tag>
```

This lays down both backends' files:

| Backend | Files |
|---------|-------|
| `python` (Azure/REST) | `lib/libsecure_invoke.so`, `lib/libcddl.so` |
| `native` (GCP/gRPC)   | `native/bin/invoke`, `native/lib/libcddl.so` |

For the native backend you can also skip the fetch and point at an existing
binary: `--native-bin /path/to/invoke` or `SECURE_INVOKE_NATIVE_BIN`. Native
binary resolution order: `--native-bin` → `SECURE_INVOKE_NATIVE_BIN` → bundled
`native/bin/invoke` → `invoke` on `PATH`.

#### Publishing the artifact

Maintainers seed the registry once with push credentials:

```bash
az acr login --name <acr-name>          # or: oras login <registry> -u .. -p ..
./scripts/publish_libs.sh           # packs lib/ + native/ and pushes the artifact
```

`publish_libs.sh` sources the GCP native binary from the GCP `secure_invoke`
image (`scripts/fetch_native.sh`) if it isn't already vendored locally.

## CLI

```bash
# List KMS public keys
secure-invoke --op keys \
  --kms-host https://depa-inferencing-kms-azure.ispirt.in --insecure

# Azure (REST)
secure-invoke \
  --kms-host https://depa-inferencing-kms-azure.ispirt.in \
  --offer-host "$OFE_IP:51052" --offer-endpoint /v1/getbids \
  --protocol rest \
  --request-file get_bids_request.json \
  --insecure

# GCP (gRPC)
secure-invoke \
  --kms-host https://p3dx-kms.iudx.org.in \
  --offer-host "ispirt-ci.bfe.example.com:443" \
  --protocol grpc \
  --request-file get_bids_request.json \
  --client-ip 192.168.1.1

# High-volume batch from a .jsonl file (one request per line)
secure-invoke --op batch --request-file requests.jsonl --max-workers 32 \
  --kms-host ... --offer-host ... --protocol grpc --cache-keys
```

Key flags: `--op {invoke,encrypt,keys,batch}`, `--protocol {rest,grpc}`,
`--backend {auto,python,native}`, `--target-service bfe`, `--native-bin`,
`--client-type {browser,android}`, `--request`/`--request-file`,
`--kms-host`/`--kms-keys-endpoint`, `--offer-host`/`--offer-endpoint`,
`--insecure`, `--client-cert/--client-key/--ca-cert`, `--headers '<json>'`,
`--client-ip`, `--retries/--retry-delay/--timeout`,
`--cache-keys/--cache-file/--cache-ttl/--cache-ignore-server-headers`,
`--verbose`. Run `secure-invoke --help` for the full list.

> `--op encrypt` (standalone ciphertext) is only available on the `python`
> backend; the `native` backend performs the round trip in a single step.

## Library

```python
from depa_secure_invoke import SecureInvokeClient, SecureInvokeConfig

cfg = SecureInvokeConfig(
    kms_host="https://p3dx-kms.iudx.org.in",   # path prefixes are preserved
    offer_host="ispirt-ci.bfe.example.com:443",
    protocol="grpc",                            # or "rest" for Azure
    client_ip="192.168.1.1",
    cache_keys=True,                            # cache pubkeys for 15m (opt-in)
)

# Reuse one client for many requests (cached key + pooled channel).
with SecureInvokeClient(cfg) as client:
    resp = client.invoke(request_file="get_bids_request.json")
    print(resp)

    results = client.invoke_batch([req1, req2, req3], max_workers=32)
```

## Public key caching

**Off by default.** When enabled, KMS public keys are reused until they expire,
so a high-volume client doesn't hit the KMS on every request (both backends
benefit — the Python KMS client fetches the key for the native/GCP path too).

**Lifetime (cache-control aware).** The TTL honors the KMS response's
`Cache-Control: max-age` / `Expires` (and `no-store`/`no-cache` disable caching).
When the KMS sends no such header, the fallback `--cache-ttl` applies (default
900 s = 15 min). Use `--cache-ignore-server-headers` to always use `--cache-ttl`.
A `Cache-Control: max-age=<ttl>` request header is also sent so intermediary
caches can cooperate.

**Scope — choose what fits your workflow:**

| How | Enable | Shared across… |
|-----|--------|----------------|
| In-process | `--cache-keys` (CLI) / `cache_keys=True` | one client instance / `--op batch` |
| On-disk    | `--cache-file PATH` / `cache_file="..."` | separate CLI invocations / processes |
| Your store | `SecureInvokeClient(cfg, key_cache=...)` | wherever your backend reaches (e.g. Redis) |

```bash
# CLI: reuse a key across repeated invocations via an on-disk cache
secure-invoke --op invoke --cache-file ~/.cache/depa/keys.json --cache-ttl 900 \
  --kms-host ... --offer-host ... --protocol grpc --request-file req.json
```

**Bring your own cache (e.g. Redis).** The SDK has no Redis dependency; implement
the small `KeyCache` interface (`get`/`set`) and inject it — the SDK still
computes the TTL and calls `set`. See `examples/redis_key_cache.py`:

```python
from depa_secure_invoke import SecureInvokeClient, SecureInvokeConfig, KeyCache

class MyRedisCache(KeyCache):
    def get(self, key): ...
    def set(self, key, value, ttl): ...

client = SecureInvokeClient(cfg, key_cache=MyRedisCache())
```

**Or manage it entirely yourself** — fetch once and pass the key back per call;
the SDK then never touches the KMS or any cache:

```python
key = client.public_key()                  # store it however you like
client.invoke(request, public_key=key)     # reuse it
```

## Docker

The image is self-contained for **both** clouds: at build time it pulls the
crypto binaries (Azure `.so` + GCP native) from the registry via ORAS
(`--build-arg SECURE_INVOKE_LIBS_REF=...`, default is the pinned artifact).

```bash
./docker/build.sh ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk:1.0.0
docker run --rm --network host \
  -v "$PWD/requests:/requests" \
  ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk:1.0.0 \
  --op invoke --protocol rest \
  --kms-host https://depa-inferencing-kms-azure.ispirt.in \
  --offer-host "$OFE_IP:51052" \
  --request-file /requests/get_bids_request.json --insecure
```

## CI/CD (build & release)

`.github/workflows/secure_invoke_build.yml` (manual `workflow_dispatch`) builds
and pushes the wheel + Docker image to ACR. Inputs:

| Input | Meaning |
|-------|---------|
| `cloud` | `azure` \| `gcp` \| `both` — which crypto backend(s) to bundle (keeps artifacts lean) |
| `release_name` | version for the wheel + image tag, e.g. `1.0.0` |
| `source_branch` | repo ref to build from |
| `libs_ref` | override the crypto-libs artifact (blank = pinned default) |
| `push_to_acr` | uncheck to build only |

It pulls the crypto binaries via ORAS, versions the wheel, prunes to the chosen
cloud, then pushes (`<tag>` = `<release>` for `both`, else `<release>-<cloud>`):

- image → `.../tools/secure_invoke_sdk:<tag>`
- wheel → `.../tools/secure_invoke_sdk_wheel:<tag>` (also a workflow artifact)

**One-time prerequisite:** the crypto-libs artifact must already exist in ACR —
publish it with `scripts/publish_libs.sh` (see "Publishing the artifact" above).

## Development

```bash
pip install -e ".[dev]"
pytest tests/                 # unit tests (no network)
./scripts/gen_proto.sh        # regenerate gRPC stubs from the .proto
```

## Layout

```
sdk/
├── pyproject.toml
├── src/depa_secure_invoke/
│   ├── client.py           # SecureInvokeClient orchestration + backend routing
│   ├── cli.py              # `secure-invoke` CLI
│   ├── config.py           # SecureInvokeConfig (+ backend selection)
│   ├── crypto.py           # python backend: ctypes over the .so (encrypt/decrypt)
│   ├── native.py           # native backend: drives the GCP `invoke` binary
│   ├── kms.py              # KMS client (path-preserving, TTL cache)
│   ├── urls.py             # path-preserving URL join
│   ├── requests_io.py      # file/inline request loading
│   ├── transport/          # rest.py + grpc_.py (python backend)
│   ├── proto/              # minimal GetBids envelope + generated stubs
│   ├── lib/                # Azure libsecure_invoke.so + libcddl.so (fetched, gitignored)
│   └── native/             # GCP invoke binary + libcddl.so (fetched, gitignored)
├── docker/                 # Dockerfile (multi-stage, ORAS fetch) + build.sh
├── scripts/                # gen_proto.sh, fetch_libs.sh, publish_libs.sh, fetch_native.sh
└── tests/
```

All heavy binaries are pulled from the registry by `fetch_libs.sh`; see
"Crypto binaries" above.
