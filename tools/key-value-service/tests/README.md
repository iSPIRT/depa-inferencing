# Key-value service Python test suite

Tests for the GetValues API of the key-value service ([query protocol](https://github.com/iSPIRT/protected-auction-key-value-service/blob/main/docs/testing_the_query_protocol.md)).

## Scenarios

1. **Structure and first delta** (`test_getvalues.py`)
   - **Structure**: GetValues returns 200 and `compressionGroups[].content` (base64); decoded content shape.
   - **First delta**: When `KV_TEST_STORAGE_*` is set, the test generates CSV (2 records, keys 0–1, seed 42), uploads `DELTA_0000000000000001`, waits, then asserts first and last key are present in getValues response.
   - Edge cases: empty keys, unknown key.

2. **Second delta / incremental load** (`test_getvalues_incremental.py`)
   - When storage is configured, the test generates CSV (2 records, keys 100–101, seed 43), uploads `DELTA_0000000000000002`, waits, then asserts first and last key are present.
   - Requires Azure Storage credentials and Docker + `data_cli.sh` for delta conversion.

## Setup

```bash
cd tools/key-value-service
pip install -r requirements-test.txt
```

## Run tests

**Against a running KV service (e.g. local or ACI):**

```bash
# Default base URL is http://localhost:51052
pytest tests/ -v

# With explicit URL (e.g. ACI IP)
KV_BASE_URL=http://20.219.215.70:51052 pytest tests/ -v

# Or
pytest tests/ -v --kv-url http://20.219.215.70:51052
```

**First-delta and incremental tests** can upload deltas from Python when Azure Storage env vars are set (Docker + `data_cli.sh` required for converting CSV to delta):

```bash
export KV_TEST_STORAGE_ACCOUNT=youraccount
export KV_TEST_STORAGE_KEY=yourkey
export KV_TEST_SHARE_NAME=fslogix
export KV_TEST_SHARE_PATH=deltas
export KV_TEST_RELOAD_WAIT_SEC=90   # optional, default 90

KV_BASE_URL=http://<KV_IP>:51052 pytest tests/ -v
```

To see when delta files are generated and uploaded, run with log level INFO:

```bash
pytest tests/ -v --log-cli-level=INFO
```

If `KV_TEST_*` storage vars are not set, incremental tests are skipped.

## GitHub workflow

The workflow scenario (upload first delta, wait, call GetValues, assert) is covered by:

- `TestGetValuesStructure.*`
- `TestGetValuesInitialDelta.*`

Run the same tests in CI by pointing `KV_BASE_URL` at the ACI IP after deploy and upload.
