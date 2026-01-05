# Release Notes: Environment Variables Changes

## Version 4.8.0.2

### Offer Service (Bidding Service)

#### Renamed Variables

- **`JS_NUM_WORKERS`** → **`UDF_NUM_WORKERS`**
  - The variable name was changed to reflect the migration from JavaScript workers to User Defined Functions (UDF) terminology.
  - **Expected Value:** `"4"` 
  - **Constraints:** Must be <= `resources.limit.cpu` of the container
  - **Example:** `"64"` (for higher CPU limits)

#### New Variables Added

- **`ENABLE_AUCTION_COMPRESSION`**
  - Description: Enable auction compression feature
  - **Expected Value:** `"false"` 


### OFE Service (Buyer Frontend Service)

#### New Variables Added

- **`ENABLE_TKV_V2`**
  - Description: Activates the new TKV (Trusted Key-Value) V2 API functionality
  - **Expected Value:** `"true"` 

- **`BUYER_TKV_V2_SERVER_ADDR`**
  - Description: Specifies the server address for TKV V2 API connections
  - **Expected Value:** `"kv.ad_selection.microsoft:51052"` 

- **`ENABLE_TKV_V2_BROWSER`**
  - Description: Enables browser-specific TKV V2 functionality
  - **Expected Value:** `"true"` 

- **`TKV_EGRESS_TLS`**
  - Description: Configures TLS settings for outbound TKV V2 traffic
  - **Expected Value:** `"false"` 

### KV Service (Key-Value Service)

#### Infrastructure Changes

- **Port Configuration**
  - **Version 4.3.0.0:** Only gRPC port (50051) was exposed
  - **Version 4.8.0.2:** Both gRPC port (50051) and HTTP port (51052) are now exposed
  - **Impact:** The service now supports both gRPC and HTTP protocols

### Global Environment Variables

#### New Variables Added

- **`AZURE_BA_PARAM_CLIENT_ID`**
  - Description: Client ID of the MI used for accessing the KMS
  - **Expected Value:** `""` (client ID of the MI, empty otherwise)

