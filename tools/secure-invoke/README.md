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
| **`BUYER_HOST`** | Host and port of the Buyer service.                         | grpc:`127.0.0.1:50051`, http(s):`127.0.0.1:51052`|
| **`HOST_REQUESTS_DIR`** | Directory containing inference request files.       | `/home/user/requests` |
| **`OPERATION`**  | Operation to be performed- http_end_point:rest_invoke, grpc_end_point:invoke, encrypt_payload:encypt, batch_processing:batch_invoke | Default: rest_invoke |
| **`RETRIES`**    | Number of retries before failing the transaction.          | Default: 1 |
| **`INSECURE`**   | Disable certification verification                         | Default: false |
| **`HEADERS`**    | Additional http headers in '{"key1"="value1", "key2"="value2", ".."}' format | '{"Authorization"="Bearer \<token\>", "API_KEY"=""}' |
| **`HOST_CERTS_DIR`** | Directory containing certificates in the container. | `/home/azureuser/certs` |
| **`CLIENT_KEY`** | Client key file                                       | `client.key` |
| **`CLIENT_CERT`**| Client certificate file                               | `client.crt` |
| **`CA_CERT`**    | CA certificate file                                  | `ca.crt` |
| **`MAX_CONCURRENT_REQUESTS`** | Maximum number of concurrent requests in batch processing. | Default: 5 |


## Batch Processing
Batch processing allows you to process multiple inference requests in a single run.

### Requirements
- Batch requests must be in JSONL (JSON Line) format, with each line containing a separate request
- Each request must include a unique integer `id` field to correlate responses with requests
- Set `OPERATION=batch_invoke` in your environment variables

### Input and Output Files
- **Input**: Place your JSONL request file in the directory specified by **HOST_REQUESTS_DIR**
- **Output**: After processing, two files will be generated in the same directory:
  - `success_log.jsonl`: Contains successful responses
  - `failure_log.jsonl`: Contains failed requests with error details

### Sample Files

**Sample request file (batch_requests.jsonl):**
```json
{"id":1,"request":{"buyerInput":{"interestGroups":[{"biddingSignalsKeys":["9999999990"],"name":"Rajini Kausalya","userBiddingSignals":"{\"age\":58, \"average_amount_spent\":50008000, \"total_spent\":100016000}"}]},"publisherName":"irctc.com","seller":"irctc.com"}}
{"id":2,"request":{"buyerInput":{"interestGroups":[{"biddingSignalsKeys":["9999999991"],"name":"Sumitra Rao","userBiddingSignals":"{\"age\":42, \"average_amount_spent\":30000000, \"total_spent\":60000000}"}]},"publisherName":"irctc.com","seller":"irctc.com"}}
```

**Sample success response (success_log.jsonl):**
```json
{"id":1,"response":{"bids":[{"ad":"ad","adComponents":["https://my-ad-component"],"adCost":2,"bid":1,"bidCurrency":"USD","debugReportUrls":{"auctionDebugLossUrl":"https://my-debug-url/loss","auctionDebugWinUrl":"https://my-debug-url/win"},"interestGroupName":"Rajini Kausalya","modelingSignals":3,"render":"https://my-render-url"}],"updateInterestGroupList":{}}}
{"id":2,"response":{"bids":[{"ad":"ad","adComponents":["https://my-ad-component"],"adCost":2,"bid":1,"bidCurrency":"USD","debugReportUrls":{"auctionDebugLossUrl":"https://my-debug-url/loss","auctionDebugWinUrl":"https://my-debug-url/win"},"interestGroupName":"Sumitra Rao","modelingSignals":3,"render":"https://my-render-url"}],"updateInterestGroupList":{}}}
```

**Sample failure response (failure_log.jsonl):**
```json
{"error":{"attempts":3,"message":"Timeout was reached"},"id":3,"request":{"buyerInput":{"interestGroups":[{"biddingSignalsKeys":["999999000"],"name":"Maya Kausalya","userBiddingSignals":"{\"age\":20, \"average_amount_spent\":10000, \"total_spent\":20000}"}]},"publisherName":"irctc.com","seller":"irctc.com"}}
```

### Best Practices
- Use the `MAX_CONCURRENT_REQUESTS` parameter to control parallelism
- Monitor both success and failure logs to track processing results


## Additional Notes
- Ensure **BUYER_HOST** and **KMS_HOST** are reachable.
- Verify that **HOST_REQUESTS_DIR** contains valid request files.

