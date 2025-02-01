**Authors:** <br>
[Kapil Vaswani](https://github.com/kapilvgit), iSPIRT<br>
[Pavan Adukuri](https://github.com/pavanad), iSPIRT

# DEPA inferencing 

DEPA aims to develop technologies that enable more private
data sharing across organization. Today, data sharing does not provide technical guarantees of
security. 

DEPA provides ways to preserve privacy and limit third-party
data sharing by serving personalized services based on data held with data providers. 

DEPA inferencing outlines a way to allow inferencing services to be hosted in cloud servers in a trusted execution
environment. 

## Useful information

## Onboarding and alpha testing guide

Following is the guide for onboarding to DEPA inferencing services and
participating in Alpha testing.
 
### Guidance to buyers / DSPs:
  * Refer to [Spec for DSP][89] section.
  * Develop [GenerateBid][69]() for bidding.
  * Setup [Key/Value service][70].
    * If your Key/Value server supports filtering of interest groups, refer to
      this [section][91] and [metadata forwarding][90].
  * [Optimise payload][51].
  * Review [Logging][93] section.
  * DEPA inferencing services code and configurations is open sourced to
    [Github repo][59].
  * Deploy [FrontEnd][22] and [Inferencing][42] server instances to your
    preferred [cloud platform that is supported][98].
  * [Enroll with coordinators][85] or run servers in `TEST_MODE`.

## Specifications for data providers and consumers

### Spec for Data consumer

#### generateBid()

The [inferencing service][42] exposes an API endpoint GenerateBids. The [FrontEnd service][22] sends
GenerateBidsRequest to the inferencing service, that includes required input for bidding. The code
for bidding, i.e. `generateBid()` is prefetched from Cloud Storage, cached and precompiled in inferencing service.
After processing the request, the inferencing service returns the GenerateBidsResponse which includes 
bids that correspond to each ad, i.e. [AdWithBid][49]. 

The function can be implemented in Javascript (or WASM driven by Javascript) or compiled into a [standalone binary][162]. The specifcation for both is described in detail below.

##### generateBid() Javascript/WASM spec 

```
generateBid(interestGroup, auctionSignals, perBuyerSignals, trustedBiddingSignals,  deviceSignals) {
  ...
  return {'ad': adObject,
          'bid': bidValue,
          'render': renderUrl,
          'adComponents': ["adComponentRenderUrlOne", "adComponentRenderUrlTwo"],
          'allowComponentAuction': false};
 } 
```

###### Arguments

* `interestGroup`: The InterestGroup object. Refer InterestGroup data structure to
  understand what is sent in this object from the client.
    * The InterestGroup is serialized and passed to generateBid() exactly as-sent, _except_ for the following divergences:
      ** `DeviceSignals` are serialized and passed separately, see below.
      ** `component_ads` are serialized in a field named `adComponentRenderIds`
      ** `bidding_signals_keys` are serialized in a field named `trustedBiddingSignalsKeys`.
    * _Note: To reduce payload over the network and further optimize latency, our goal is to minimize
      the information sent in this object. We will work with data consumers for the long term to reduce the
      amount of information sent in this object and try to find a solution to fetch those on the server
      side._

* `auctionSignals`: Empty.

* `perBuyerSignals`: Empty 

* `trustedBiddingSignals`: Real time signals fetched by FrontEnd service from Key/Value
  service. 
  * _Note: Only the `trustedBiddingSignals` required for generating bid(s) for the `interestGroup` are
    passed to `generateBid()`_.

* `deviceSignals`: Empty

##### generateBid() Binary spec 
The signature for the GenerateBid binary is specified as proto objects. That means, the input to the GenerateBid binary will be a proto object and the output will be a proto object. The function signature looks like this - 

```
GenerateProtectedAudienceBidResponse generateBid(GenerateProtectedAudienceBidRequest);
```

The definition for these high level protos along with nested types is specified in the [API code][160]. This is different from the Javascript signature - the parameters and return values are encapsulated in high level proto objects. These differences are discussed as follows.

###### Arguments
* `GenerateProtectedAudienceBidRequest`: This is the request object that encapsulates all the arguments for the generateBid() UDF (similar to the parameters in the JS spec for generateBid like interestGroup, deviceSignals, etc.). 
```
message GenerateProtectedAudienceBidRequest {
  ProtectedAudienceInterestGroup interest_group = 1 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'This will be prepared by the Bidding service based on the data received'
      ' in the BuyerInput from the device.'
}];

  string auction_signals = 2 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'Auction signals are sent by the seller in the Auction Config. This can'
      ' be encoded any way by the seller and will be passed as-is to the'
      ' generateBid() UDF.'
}];

  string per_buyer_signals = 3 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'Per buyer signals are sent by the seller in the Auction Config. This can'
      ' be encoded any way by the seller and will be passed as-is to the'
      ' generateBid() UDF.'
}];

  string trusted_bidding_signals = 4 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'This will be passed as the JSON response received from the buyer\'s'
      ' key/value server.'
}];

  oneof ProtectedAudienceDeviceSignals {
    ProtectedAudienceAndroidSignals android_signals = 5 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
        'This will be prepared by the Bidding server based on information'
        ' passed by the Android app.'
}];

    ProtectedAudienceBrowserSignals browser_signals = 6 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
        'This will be prepared by the Bidding server based on information'
        ' passed by the browser on desktop or Android.'
}];

    ServerMetadata server_metadata = 7 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
        'This will be prepared by the Bidding server and will contain config'
        ' information about the current execution environment.'
}];
  }
}
```
  * `ServerMetadata`: The server passes additional config information for the current execution in the ServerMetadata message. This will inform the binary if logging or debug reporting functionality is available for the current execution.
```
message ServerMetadata {
  option (privacysandbox.apis.roma.app_api.v1.roma_mesg_annotation) = {description:
      'Config information about the current execution environment for a'
      ' GenerateBidRequest.'
};

  bool debug_reporting_enabled = 1 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'A boolean value which indicates if event level debug reporting is'
      ' enabled or disabled for the request. Adtechs should only return debug'
      ' URLs if this is set to true, otherwise the URLs will be ignored and'
      ' creating these will be wasted compute.'
}];

  bool logging_enabled = 2 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'A boolean value which indicates if logging is enabled or disabled for'
      ' the request. If this is false, the logs returned from the RPC in the'
      ' response will be ignored. Otherwise, these will be outputted to the'
      ' standard logs or included in the response.'
}];
}
```

* `GenerateProtectedAudienceBidResponse`: This is the response field expected from the generateBid UDF. It contains the bid(s) for ad candidate(s) corresponding to a single Custom Audience (a.k.a Interest Group) (similar to the return values from the JS spec for generateBid).

```
message GenerateProtectedAudienceBidResponse {
  repeated ProtectedAudienceBid bids = 1 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'The generateBid() UDF can return a list of bids instead of a single bid.'
      ' This is added for supporting the K-anonymity feature. The maximum'
      ' number of bids allowed to be returned is specified by the seller. When'
      ' K-anonymity is disabled or not implemented, only the first candidate'
      ' bid will be considered.'
}];

  LogMessages log_messages = 2 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {description:
      'Adtechs can add logs to the response if logging was enabled in the'
      ' request. Logs will be printed out to the console in case of non-prod'
      ' builds and added to the server response in case of debug consented'
      ' requests.'
}];
}
```
  * `DebugReportUrls`: URLs to support debug reporting, when auction is won and auction is lost. There is no [forDebuggingOnly][163] method/API and the debug URLs for a bid have to be directly included by the binary in the proto response. These can be added in the DebugReportUrls field in the [ProtectedAudienceBid][165] proto. The [format][164] for the URLs stays the same as the browser definition and they will be pinged in the exact same way.
```
message DebugReportUrls {
   string auction_debug_win_url = 1 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = 
   {description:'URL to be triggered if the Interest Group wins the auction. If undefined'
      ' or malformed, it will be ignored.'
  }];

    string auction_debug_loss_url = 2 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = {
      description:'URL to be triggered if the Interest Group loses the auction. If'
        ' undefined or malformed, it will be ignored.'
  }];
}
```

  * `LogMessages`: The standard logs from the binary [are not exported for now][161] (This will be added later on in 2025). For now, any logs from the binary will be discarded. As a workaround, the GenerateProtectedAudienceBidResponse proto includes the log_messages field  for logs and error messages. 
```
message LogMessages {
  option (privacysandbox.apis.roma.app_api.v1.roma_mesg_annotation) = 
  {description: 'Logs, errors, and warnings populated by the generateBid() UDF.'};

  repeated string logs = 1 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = 
  {description: 'Optional list of logs.'}];

  repeated string errors = 2 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = 
  {description: 'Optional list of errors.'}];

  repeated string warnings = 3 [(privacysandbox.apis.roma.app_api.v1.roma_field_annotation) = 
  {description: 'Optional list of warnings.'}];
}

```
The logs, errors and warnings in this proto will be printed to the cloud logs in non_prod builds, and included in the server response in case of consented debug requests. 
 

#### Key/Value service

_Note: BYOS Key/Value is only supported for Chrome. Protected Auctions using data from Android
devices are required to use the [Protected Auction Key/Value service][166]._

The [BuyerFrontEnd service][22] looks up biddingSignals from Buyer's BYOS Key/Value service. The base url
(domain) for Key/Value service is configured in BuyerFrontEnd service so that the connection can be
prewarmed. All lookup keys are batched together in a single lookup request. The lookup url and response
are in the same format as described in [Chrome Protected Audience explainer][40].

The lookup url is the following format:

```
<base_url>/getvalues?hostname=<publisher.com>&experimentGroupId=<kv_exp_id>&keys=<key_1>,..
<key_n>

Where <base_url>, <publisher.com>, <kv_exp_id>, key_1>,...<key_n> are substituted

Note: If keys are the same as InterestGroups names, then those are not looked up more than once.
```

The response is in the following format:

```
{ 'keys': {
      'key1': arbitrary_json,
      'key2': arbitrary_json,
      ...},
  'perInterestGroupData': {
      'name1': {
      },
      ...
  }
}
```

_Note: The `trustedBiddingSignals` passed to `generateBid()` for an Interest Group (Custom Audience) is
the value corresponding to each lookup key in the Interest Group but not the entire response.
Following is an example, if key1 is the lookup key in an interest group, then the following is passed
to `generateBid()` in `trustedBiddingSignals`._

```
  'key1': arbitrary_json
```

##### Filtering in buyer's Key/Value service

Filtering interest groups in buyer's Key/Value service can help reduce number
of interest groups for bidding; and therefore optimize latency and reduce cost of 
Bidding service.

To support filtering of interest groups in buyer's BYOS Key/Value service, metadata
received from the client will be forwarded in the HTTP request headers of the
`trustedBiddingSignals` lookup request.

Refer to [metadata forwarding][90] for more details.

#### Buyer service configurations

Server configurations are based on [Terraform][16] and is open sourced to [Github repo][59] for
cloud deployment. 

The configurations will include environment variables and parameters that may vary per buyer.
These can be set by the buyer in the configuration before deployment. The configurations also 
include urls that can be ingested when the service starts up for prewarming the connections.  

Refer to the [README for deployment on AWS][106] or [README for deployment on GCP][105]. Refer to 
[example config on AWS][100] or [example config on GCP][102] for the Terraform config required
for deployment to the cloud. The config requires update of some parameter values (that vary
per adtech) before deployment to cloud.

Following are some examples of data configured in service configurations. 

##### BuyerFrontEnd service configurations

* _Buyer's Key/Value service endpoint (bidding_signals_url)_: This endpoint is configured in BuyerFrontEnd
  service configuration and ingested at service startup to prewarm connections to buyer's Key/Value service.

* _Bidding service endpoint_: The domain address of Bidding service. This is ingested at service startup to
  prewarm connection.

* _Private Key Hosting service_ and _Public Key Hosting service_ endpoints in [key management systems][10].

##### Bidding service configurations

* _Cloud Storage endpoint_: The endpoint of Cloud Storage from where buyer's code is hot reloaded by the
  Bidding service.

* _Private Key Hosting service_ and _Public Key Hosting service_ endpoints in [key management systems][10].




### Adtech code 

Adtech code for `generateBid()`, `scoreAd()`, `reportResult()`, `reportWin()` can follow
the same signature as described in the [Protected Audience API for the browser][28]. 

_Note:_
  * Code can be Javascript only or WASM only or WASM instantiated with Javascript.
  * If the code is in Javascript, then Javascript context is initialized before every execution.
  * No limit on code blob size.
  * More than one version of code can be supported to facilitate adtech experimentation.
  * Adtech can upload their code to Cloud Storage supported by the Cloud Platform.
  * Code is prefetched by Bidding / Auction services running in [trusted execution environment][29]
    from the Cloud Storage bucket owned by adtech.

Refer to more details [here][86].

### Cloud deployment

Bidding and Auction services are deployed by adtechs to a [public cloud platform][98] so that they are
co-located within a cloud region. 

Servers can be replicated in multiple cloud regions and the availability Service-Level-Objective (SLO)
will be decided by adtechs. 

#### SSP system

There will be a Global Load balancer for managing / routing public traffic to [SellerFrontEnd service][21].
Traffic between SellerFrontEnd and Auction service would be over private VPC network. To save cost,
SellerFrontEnd and Auction server instances will be configured in a [service mesh][87].

#### DSP system

There will be a Global Load balancer for managing / routing public traffic to [BuyerFrontEnd services][22].
Traffic between BuyerFrontEnd and Bidding service would be over private VPC network. To save cost,
BuyerFrontEnd and Bidding server instances will be configured in a [service mesh][87].

### Logging

#### Debug / non-prod build

Bidding and Auction server logs will be available with debug (non-prod) build / mode. The debug binaries 
can be built with higher [level of verbose logging](https://github.com/google/glog#verbose-logging).
For GCP, these logs will be exported to [Cloud Logging][65].

The [context logger](#logcontext) in Bidding and Auction servers supports logging `generation_id`
passed by the client in encrypted [ProtectedAudienceInput][9] and optional
(per) `buyer_debug_id` and `seller_debug_id` passed in [`SelectAdRequest.AuctionConfig`][35] for 
an ad request. The `adtech_debug_id` (`buyer_debug_id` or `seller_debug_id`) can be an internal 
log / query id used in an adtech's non TEE based systems and if available can help the adtech trace
the ad request log in Bidding and Auction servers and map with the logs in their non TEE based systems.

Logs from adtech's code can be made available in debug mode.

#### Production build

Bidding and Auction servers will support safe logging in production mode and the logs will be
exported to Cloud Logging / Cloud Watch. Refer [Debugging Protected Audience API services][60]
for more details.

Logs from adtech's code can be made available if [adtech / user consented debugging][92] is enabled. 

### Dependencies

Through techniques such as prefetching and caching, the following dependencies are in the non-critical
path of ad serving.

#### Key management systems

The [key management systems][10] are required for Protected Audience service attestation and cryptographic
key generation. Learn more in the [Overview of Protected Audience Services Explainer][6]. The 
key management systems will be deployed to all supported public clouds. Services in the key management
systems will be replicated in multiple cloud regions. 

All services running in TEE prefetch encryption and decryption keys from key management systems at service
startup and periodically in the non critical path. All communication between a service in TEE and another
service in TEE is end-to-end encrypted using Hybrid Public Key Encryption and TLS. Refer [here][11] for more
details.

## Service APIs

Refer to Bidding and Auction services APIs [in open source repo][121].

### Client <> server data

Following section describes the data that flows from client (e.g. browser, Android) to Bidding and Auction
Services through [Seller Ad service][20] and the data received by client from Bidding and Auction Services.

#### ProtectedAudienceInput

ProtectedAudienceInput is built and encrypted by client (browser, Android). Then sent to [Seller Ad service][20] in
the [unified request][83]. This includes per [BuyerInput](#buyer-input) and other required data.

Refer to [ProtectedAudienceInput message][108].

#### BuyerInput

BuyerInput is part of [ProtectedAudienceInput][9]. This includes data for each buyer / DSP.

Refer to [BuyerInput message][109].

#### BrowerSignals
Information about an Interest Group known to the browser. These are required to
generate bid.

Refer to [BrowserSignals message][110].

#### AndroidSignals
Information passed by Android for Protected Audience auctions. This will be 
updated later.

Refer to [AndroidSignals message][111].

#### AuctionResult

Protected Audience auction result returned from SellerFrontEnd service to the client through the Seller
Ad service. The data is encrypted by SellerFrontEnd service and decrypted by the client. The
Seller Ad service will not be able to decrypt the data. 

In case the contextual ad wins, an AuctionResult will still be returned that includes fake data
and has is_chaff field set to true. Clients should ignore AuctionResult after decryption if
is_chaff is set to true.

Refer to [AuctionResult message][112].

### Public APIs

#### SellerFrontEnd service and API endpoints

The SellerFrontEnd service exposes an API endpoint (SelectAd). The Seller Ad service would send
a SelectAd RPC or HTTPS request to SellerFrontEnd service. After processing the request,
SellerFrontEnd would return a SelectAdResponse that includes an encrypted AuctionResult. 

The AuctionResult will be encrypted in SellerFrontEnd using [Oblivious HTTP][50] that is based on
bidirectional [HPKE][48].

Refer to the [API][113].

#### LogContext 

Context for logging requests in Bidding and Auction servers. This includes `generation_id`
passed by the client in encrypted [ProtectedAudienceInput][9] and optional
(per) `buyer_debug_id` and `seller_debug_id` passed in [`SelectAdRequest.AuctionConfig`][35].
The `adtech_debug_id` (`buyer_debug_id` or `seller_debug_id`) can be an internal log / query id
used in an adtech's non TEE based systems and if available can help the adtech trace the ad request 
log in Bidding and Auction servers and map with the logs in their non TEE based systems.

Refer to the [LogContext message][114].

#### BuyerFrontEnd service and API endpoints

The BuyerFrontEnd service exposes an API endpoint GetBids. The SellerFrontEnd service sends
encrypted GetBidsRequest to the BuyerFrontEnd service that includes BuyerInput and other data.
After processing the request, BuyerFrontEnd returns GetBidsResponse, which includes bid(s) for
each Interest Group. Refer to [AdWithBid][49] for more information.

The communication between the BuyerFrontEnd service and the SellerFrontEnd service is TEE to TEE
communication and is end-to-end encrypted using [HPKE][48] and TLS/SSL. The communication will happen
over public network and that can also be cross cloud networks.

Refer to the [API][115].

##### AdWithBid

The AdWithBid for an ad candidate, includes `ad` (i.e. ad metadata), `bid`, `render` (i.e. ad render url),
`allow_component_auction` and `interest_group_name`. This is returned in GetBidsResponse by
BuyerFrontEnd to SellerFrontEnd.

Refer to the [AdWithBid message][116].

### Internal API

Internal APIs refer to the interface for communication between Protected Audience services within a SSP
system or DSP system.

#### Bidding service and API endpoints

The Bidding service exposes an API endpoint GenerateBids. The BuyerFrontEnd service sends
GenerateBidsRequest to the Bidding service, that includes required input for bidding. The code for
bidding is prefetched from Cloud Storage and cached in Bidding service. After processing the request,
i.e. generating bids, the Bidding service returns the GenerateBidsResponse to BuyerFrontEnd service.

The communication between the BuyerFrontEnd service and Bidding service occurs between each service’s TEE
and request-response is end-to-end encrypted using [HPKE][48] and TLS/SSL. The communication also happens
over a private VPC network.

Refer to the [API][117].

#### Auction service and API endpoints

The Auction service exposes an API endpoint ScoreAds. The SellerFrontEnd service sends a
ScoreAdsRequest to the Auction service for running auction; ScoreAdsRequest includes bids from
each buyer and other required signals. The code for auction is prefetched from Cloud Storage and
cached in Auction service. After all ads are scored, the Auction service picks the highest scored
ad candidate and returns the score and other related data for the winning ad in ScoreAdsResponse.

The communication between the SellerFrontEnd service and Auction service occurs within each service’s
TEE and request-response is end-to-end encrypted using [HPKE][48] and TLS/SSL. The communication also
happens over a private VPC network.

Refer to the [API][118].

#### WinReporting Urls

Refer to [WinReportingUrls message][119].

#### DebugReporting Urls

Refer to [DebugReportingUrls message][120].

[4]: https://privacysandbox.com
[5]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md
[6]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md
[7]: https://developer.android.com/design-for-safety/privacy-sandbox/protected-audience-bidding-and-auction-integration
[8]: https://github.com/WICG/privacy-preserving-ads/tree/main?tab=readme-ov-file#ad-selection-api-proposal
[9]: #protectedaudienceinput
[10]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#key-management-systems
[11]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#fledge-services
[12]: https://grpc.io
[13]: https://developers.google.com/protocol-buffers
[14]: https://en.wikipedia.org/wiki/Interface_description_language
[15]: https://developers.google.com/protocol-buffers/docs/proto3
[16]: https://www.terraform.io/
[17]: https://github.com/privacysandbox
[18]: https://developers.google.com/protocol-buffers/docs/proto3#json
[19]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#client-to-service-communication
[20]: #seller-ad-service
[21]: #sellerfrontend-service
[22]: #buyerfrontend-service
[23]: #auction-service
[24]: https://developer.android.com/design-for-safety/privacy-sandbox/fledge
[25]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#21-initiating-an-on-device-auction
[26]: https://github.com/chatterjee-priyanka
[27]: https://developer.chrome.com/blog/bidding-and-auction-services-availability
[28]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md
[29]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#trusted-execution-environment
[30]: https://aws.amazon.com/ec2/nitro/nitro-enclaves/
[31]: https://cloud.google.com/blog/products/identity-security/announcing-confidential-space
[32]: https://cloud.google.com/confidential-computing
[33]: https://github.com/privacysandbox
[34]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md
[35]: #sellerfrontend-service-and-api-endpoints
[36]: #buyerfrontend-service-and-api-endpoints
[37]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#23-scoring-bids
[38]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding
[39]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Encoding
[40]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#31-fetching-real-time-data-from-a-trusted-server
[41]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#32-on-device-bidding
[42]: #bidding-service
[43]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#5-event-level-reporting-for-now
[44]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#35-filtering-and-prioritizing-interest-groups
[45]: https://www.envoyproxy.io/
[46]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
[47]: https://github.com/grpc/grpc-go/blob/master/Documentation/grpc-metadata.md#constructing-metadata
[48]: https://datatracker.ietf.org/doc/rfc9180/
[49]: #adwithbid
[50]: https://datatracker.ietf.org/wg/ohttp/about/
[51]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding-auction-services-payload-optimization.md
[52]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_aws_guide.md
[53]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md
[54]: https://github.com/WICG/turtledove/blob/main/FLEDGE_browser_bidding_and_auction_API.md
[55]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_multi_seller_auctions.md
[56]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md
[57]: https://github.com/privacysandbox/fledge-docs#bidding-and-auction-services
[58]: https://github.com/privacysandbox/fledge-docs#server-productionization
[59]: https://github.com/privacysandbox/bidding-auction-servers
[60]: https://github.com/privacysandbox/fledge-docs/blob/main/debugging_protected_audience_api_services.md
[61]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#adtech-code-execution-engine
[62]: https://github.com/privacysandbox/fledge-docs/blob/main/monitoring_protected_audience_api_services.md
[63]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#fake-requests--chaffs-to-dsp
[64]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#code-blob-fetch-and-code-version
[65]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md#cloud-logging
[66]: #protectedaudienceinput
[67]: #scoread
[68]: #seller-byos-key-value-service
[69]: #generatebid
[70]: #buyer-byos-keyvalue-service
[71]: #sellerfrontend-service-configurations
[72]: #auction-service-configurations
[73]: #buyerfrontend-service-configurations
[74]: #bidding-service-configurations
[75]: #reportresult
[76]: #reportwin
[77]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#sellers-ad-service
[78]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#sellerfrontend-service
[79]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#auction-service
[80]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#buyerfrontend-service
[81]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#bidding-service
[82]: #buyerinput
[83]: #unified-request
[84]: #auctionresult
[85]: #enroll-with-coordinators
[86]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#adtech-code-execution-engine
[87]: https://en.wikipedia.org/wiki/Service_mesh
[88]: #spec-for-ssp
[89]: #spec-for-dsp
[90]: #metadata-forwarding
[91]: #filtering-in-buyers-keyvalue-service
[92]: https://github.com/privacysandbox/fledge-docs/blob/main/debugging_protected_audience_api_services.md#adtech-consented-debugging
[93]: #logging
[94]: #metadata-added-by-client
[95]: #metadata-forwarded-by-sellers-ad-service
[96]: #metadata-forwarded-by-sellerfrontend-service
[97]: #metadata-forwarded-by-buyerfrontend-service
[98]: #supported-public-cloud-platforms
[100]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/buyer/buyer.tf
[101]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/seller/seller.tf
[102]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/buyer/buyer.tf
[103]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/seller/seller.tf
[104]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/packaging/README.md
[105]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/README.md
[106]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/README.md
[107]: https://cloud.google.com/iam/docs/service-account-overview
[108]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L27
[109]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L51
[110]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L118
[111]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L136
[112]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L143
[113]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L210
[114]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L369
[115]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L380
[116]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L459
[117]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L503
[118]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L638
[119]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L867
[120]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto#L892
[121]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto
[122]: https://cbor.io/
[123]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/services/seller_frontend_service/schemas/auction_request.json
[124]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/services/seller_frontend_service/schemas/interest_group.json
[125]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/services/seller_frontend_service/schemas/auction_response.json
[126]: #web-platform-schemas
[127]: #timeline-and-roadmap
[128]: #onboarding-and-alpha-testing-guide
[129]: #specifications-for-adtechs
[130]: #high-level-design
[131]: #service-apis
[132]: #data-format
[133]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_multi_seller_auctions.md#device-orchestrated-component-auctions
[134]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_multi_seller_auctions.md#server-orchestrated-component-auction
[135]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_event_level_reporting.md
[136]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/secure_invoke
[137]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/secure_invoke/README.md
[138]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/public_cloud_tees.md
[139]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/monitoring_protected_audience_api_services.md#list-of-metrics
[140]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/monitoring_protected_audience_api_services.md
[141]: https://github.com/WICG/privacy-preserving-ads/blob/main/Auction%20&%20Infrastructure%20Design.md#infrastructure-design-elements
[142]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_protected_app_signals.md
[143]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/protected_audience_auctions_mixed_mode.md
[144]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_onboarding_self_serve_guide.md
[145]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/monitoring_protected_audience_api_services.md
[146]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/debugging_protected_audience_api_services.md
[147]: https://github.com/privacysandbox/protected-auction-services-docs/tree/main?tab=readme-ov-file#protected-auction-services-documentation
[148]: https://en.wikipedia.org/wiki/Supply-side_platform
[149]: https://en.wikipedia.org/wiki/Demand-side_platform
[150]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding-auction-services-payload-optimization.md#payload-optimization-guide-for-sellers--ssps
[151]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/roma_bring_your_own_binary.md
[152]: https://developers.google.com/privacy-sandbox/private-advertising/protected-audience/android/protected-app-signals
[153]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_system_design.md#adtech-code-execution-engine
[154]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_cost.md
[155]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/protected_app_signals_cost.md
[156]: https://github.com/WICG/protected-auction-services-discussion
[157]: https://github.com/privacysandbox/bidding-auction-servers/releases
[158]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#1-browsers-record-interest-groups
[159]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding-auction-services-payload-optimization.md#payload-optimization-guide-for-buyers--dsps
[160]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/udf/generate_bid.proto
[161]: https://github.com/privacysandbox/data-plane-shared-libraries/blob/main/docs/roma/byob/sdk/docs/udf/Communication%20Interface.md#standard-output-stdout
[162]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/roma_bring_your_own_binary.md
[163]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#71-fordebuggingonly-fdo-apis
[164]: https://github.com/WICG/turtledove/blob/main/FLEDGE.md#711-post-auction-signals
[165]: https://github.com/privacysandbox/bidding-auction-servers/blob/722e1542c262dddc3aaf41be7b6c159a38cefd0a/api/udf/generate_bid.proto#L261
[166]: https://github.com/privacysandbox/protected-auction-key-value-service
[167]: https://azure.microsoft.com/