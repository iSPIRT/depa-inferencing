# DEPA Inferencing Alpha Testing Guide

This explainer describes the process for data providers and data consumers to test DEPA inferencing during Alpha. During this phase, our focus is on addressing the use case of real-time sharing of personal data between a data provider (1P) who has an existing relationship with data principals, and a 3P data consumer who wishes to provide additional services to those data principals based on personal data obtained from the data provider. 

## Interest groups

During alpha, personal data is represented as [interest groups][1]. Interest groups represent a shared interest of a cohort of users. For example, an interest group can represent females over the age of 50 who use credit cards for payments. 

Interest groups are JSON objects with the following fields.

```json
{
  {
    "name": "",
    "bidding_signals_keys": [
    ],    
    "user_bidding_signals": [
    ],
    "ad_render_ids": [
    ],
    "browser_signals": {
        "bid_count": "",
        "join_count": "",
        "prev_wins": "[]"
    },
  }
}
```

- **name**. This is the name of the interest group.  During alpha, this may be mapped to the name of the data principal.
- **bidding_signal_keys**. This is an array of strings that will be used to lookup the data consumer's key value service and retrieve additional signals that can be added to the data before inferencing. During alpha, this may include identifiers such as mobile number and/or email addresses. 
- **user_bidding_signals**. This is an array of additional attributes about the data principal that may be used during inferencing. 
- **ad_render_ids**. This is a pre-agreed list of ad campaigns or offers that may be offered to the data principal. This can be in the form of IDs or URLs. 
- **browser_signals**. This object contains additional historical information that the data provider may wish to share with the data consumer. It includes the following fields. 
  - **bid_count**. Number of times this data principal has previously been shown an offer from this data consumer. 
  - **join_count**. _Reserved for future use._
  - **prev_wins**. _Reserved for future use._

_During alpha, data providers and consumers can define interest groups as per their use case. The name of these fields and the values they are permitted to carry are subject to change beyond alpha. There will be restrictions to ensure that data shared with 3P data consumers is minimized in accordance with the privacy principles of DEPA inferencing._

## Data consumer

### Key-Value Data Preparation
DEPA inferencing enables data consumers to enrich data originating from the data provider with their own data in real-time. Data consumers must organize the data into key-value pairs; see [data format specification][5] for a full specification of the data formats supported by the KV service. 

The following csv example shows a sample CSV file containing key-value pairs, where keys are mobile numbers and values are pre-computed offers. In this case, each value is a combination of a card that the data principal is eligible for and the limit on the card.

```
key,mutation_type,logical_commit_time,value,value_type
9999999990,UPDATE,1680815895468055,PLATINUM_CARD|60000,string
9999999991,UPDATE,1680815895468056,GOLD_CARD|40000,string
9999999992,UPDATE,1680815895468057,CASH_CARD|20000,string
```

Data consumers can use the [data_cli][7] tool to convert this CSV file into a SNAPSHOT file, which can be loaded into the key-value service. 

### Developing inferencing models

Data consumers can create and deploy their own models and rule engines to process requests and generate offers. DEPA inferencing supports rule engines in a combination of Javascript, WASM, and Tensorflow/PyTorch models. 

Javascript models must implement the ```generateBids``` function with the following signatures. 

```Javascript
async function generateBids(interestGroup, auctionSignals, perBuyerSignals, trustedBiddingSignals, browserSignals) {
 ...
  return {
    bid: "",
    render: ""
    ad: {
    },
  };
}
```

The function takes the following arguments. 
- **interestGroup**. An interest group in the request from the data provider. 
- **auctionSignals**. Reserved for future use. 
- **perBuyerSignals**. user_bidding_signals in the request from the data provider. 
- **trustedBiddingSignals**. Key-values retrieved from the key-value service.
- **browserSignals**. **browser_signals*** in the request from the data provider. 

The function can perform any computation using these3 arguments, including invocation of wasm modules or TensorFlow/PyTorch models. However, it does not have access to any IO. It must return an object with the following attributes. 
- **render**. A URL that identifies the offer that can be presented to the data principal. 
- **bid**. Reserved for future. 
- **ad**. An optional opaque object returns to the data provider. Can be any value. 

### Deployment

Data consumers use the Terraform scripts provided in this repo to deploy DEPA inferencing services in a supported cloud provider. The result of a deployment is a FQDN that data consumers can share with data providers. 

### Data loading

At any point before or after deploying the services, data consumers can load their datasets (either as SNAPSHOT or DELTA files) into the key-value service. Refer to [data loading][6] for a specification of data loading capabilities of the key-value service. Data consumers can verify that data has been loaded through logs from the open telemetry collector. 

## Data Provider

Once interest groups are defined, data providers can integrate DEPA inferencing into their applications. Applications generate [requests][2] containing payloads in the following format. 

```json
{
    "client_type": "CLIENT_TYPE_BROWSER",
    "buyer_input": {
        "interest_groups": [
            {
                "name": "",
                "bidding_signals_keys": [
                ],
                "ad_render_ids": [
                ],
                "user_bidding_signals": "[]",
                "browser_signals": {
                    "join_count": "",
                    "bid_count": "",
                    "prev_wins": "[]"
                }
            }
        ]
    },
    "publisher_name": "example.com",
    "buyer_signals": "{}",
    "auction_signals": "{}",
    "seller": "",
    "log_context": {
        "generation_id": "",
        "adtech_debug_id": ""
    },
    "consented_debug_config": {
        "is_consented": true,
        "token": "123456"
    }
}
```

Requests contain the following fields:
- **client_type**. Type of end user's device / client where the request originates.
- **buyer_input**. Set of interest groups that represent interests of the data principal. 
- **publisher_name**. Name of website or app where the request originates. 
- **buyer_signals**. Additional contextual information that the data provider may wish to include in the request. This is an arbitrary JSON object. 
- **auction_signals**. _Reserved for future use._
- **seller**. _Reserved for future use._
- **log_context**. _Reserved for future use._
- **consented_debug_config**. _Reserved for future use._
Next, data providers encrypt the payload using [HPKE][3] and send encrypted requests to data consumer's inferencing services. Data providers can use the [secure_invoke][4] tool to encrypt and send requests. 

[1]: https://developers.google.com/privacy-sandbox/private-advertising/protected-audience#interest-group-detail
[2]: https://github.com/privacysandbox/bidding-auction-servers/blob/332e46b216bfa51873ca410a5a47f8bec9615948/api/bidding_auction_servers.proto#L394
[3]: https://datatracker.ietf.org/doc/rfc9180/
[4]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/secure_invoke
[5]: https://github.com/privacysandbox/protected-auction-key-value-service/blob/release-1.1/docs/data_loading/data_format_specification.md
[6]: https://github.com/privacysandbox/protected-auction-key-value-service/blob/release-1.1/docs/data_loading/data_loading_capabilities.md