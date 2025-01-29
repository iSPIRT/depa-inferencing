# DEPA Inferencing Alpha Testing Guide

This explainer describes the process for data providers and data consumers to test DEPA inferencing during Alpha. During Alpha, our focus is on addressing the use case of real-time sharing of personal data for the purpose of cross-selling. We assume there is a data provider (1P) who has an existing relationship with data principals, and a 3P data consumer who wishes to provide additional services to those data principals based on personal data obtained from the data provider. 

## Interest groups

In DEPA inferencing, personal data is represented as [interest groups][1]. Interest groups represent a share interest of a cohort of users. For example, an interest group can represent females over the age of 50 who use credit cards for payments. 

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
        "bid_count": "1",
        "join_count": "2",
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
  - **join_count**. Must be set to 0 during alpha. Reserved for future use. 
  - **prev_wins**. Must be set to 0 during alpha. Reserved for future use. 

_Note that the name of these fields and the values they are permitted to carry are subject to change beyond alpha. There will be restrictions to ensure that data shared with 3P data consumers is minimized in accordance with the privacy principles of DEPA inferencing._

## Data Provider

DEPA inferencing enables data providers to share personal data belonging to the data principal with data consumers in the form of interest groups. Data consumers can use this information to provide additional personalized services to data principals. 

Data providers can integrate DEPA inferencing into their applications using various clients. These clients construct [requests][2] in the following format. 

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
- **client_type**. Type of end user's device / client where the request originates 
- **buyer_input**. Set of interest groups that represent interests of the data principal. 
- **publisher_name**. Name of website or app where the request originates. 
- **buyer_signals**. Additional contextual information that the data provider may wish to include in the request. This is an arbitrary JSON object. 
- **auction_signals**. Reserved for future use. 
- **seller**. Reserved for future use. 
- **log_context**. Reserved for future use. 
- **consented_debug_config**. Reserved for future use. 

Next, data providers encrypt requests using [HPKE][3]. 

[1]: https://developers.google.com/privacy-sandbox/private-advertising/protected-audience#interest-group-detail
[2]: https://github.com/privacysandbox/bidding-auction-servers/blob/332e46b216bfa51873ca410a5a47f8bec9615948/api/bidding_auction_servers.proto#L394
[3]: HPKE

