# Secure Invoke Tool

## Overview
The **Secure Invoke Tool** is a script designed to securely invoke an inference service using specified environment variables.

## Usage
To execute the `secure-invoke-test.sh` script, run:

```sh
./secure-invoke-test.sh
```

## Prerequisites
Before running the script, ensure that:

- The script has **executable permissions**:
  ```sh
  chmod +x secure-invoke-test.sh
  ```
- A `.env` file is set up with the following environment variables.

## Configurable Parameters
Set the following parameters in the `.env` file:

| Parameter         | Description                                                 | Example |
|------------------|-------------------------------------------------------------|---------|
| **`KMS_HOST`**   | Host and port of the KMS service.                           | `127.0.0.1:8000` |
| **`BUYER_HOST`** | Host and port of the Buyer service.                         | `127.0.0.1:50051` |
| **`HOST_REQUESTS_DIR`** | Directory containing inference request files.       | `/home/user/requests` |
| **`RETRIES`**    | Number of retries before failing the transaction.          | Default: `1` |

## Additional Notes
- Ensure **BUYER_HOST** and **KMS_HOST** are reachable.
- Verify that **HOST_REQUESTS_DIR** contains valid request files.




