# Secure Invoke Tool

## Overview
The **Secure Invoke** is used to send **inference requests** directly to **Frontend** service. The tool takes as input an unencrypted request in JSON format and then serializes, compresses, pads and then encrypts it with keys obtained from KMS service. The response returned by the target service is then similarly decrypted, decompressed, deserialized and printed to console.

## Usage
To execute the `secure-invoke-test.sh` script, run:

```sh
./secure-invoke-test.sh
```

## Prerequisites
Before running the script, ensure that:

- Create a directory and create the **inference-request** as JSON object in "get_bids_request.json" file under the directory. Sample JSON can be found [here](https://github.com/iSPIRT/depa-inferencing/blob/main/docs/depa_inferencing_alpha.md#data-provider). This directory will be passed as environment variable as shown below to mount the /requests path of the container, where the tool expects to have "get_bids_request.json" file.

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
