# Secure Invoke Tool - README

## Overview
The **Secure Invoke Tool** is a script used to test secure invocation of inference service with specified environment variables. 

## Usage
To run the `secure-invoke-test.sh` script, use the following command format:

```sh
./secure-invoke-test.sh BUYER_HOST="<buyer_host_address>" INFERENCE_REQUESTS_DIR=<requests_directory>
```

## Example Execution
```sh
./secure-invoke-test.sh BUYER_HOST="127.0.0.1:50051" INFERENCE_REQUESTS_DIR=/home/user/requests
```

### Explanation of Arguments
- **`BUYER_HOST`**: Specifies the host and port of the buyer service.
  - Example: `127.0.0.1:50051`
- **`INFERENCE_REQUESTS_DIR`**: Path to the directory containing inference request files.
  - Example: `/home/user/requests`

## Prerequisites
Ensure the following before running the script:
- The `secure-invoke-test.sh` script has **execute permissions**:
  ```sh
  chmod +x secure-invoke-test.sh
  ```
- The specified **BUYER_HOST** is reachable.
- The **INFERENCE_REQUESTS_DIR** contains valid request files.


### 📌 **For further information, refer to the tool's documentation or contact the support team.**

