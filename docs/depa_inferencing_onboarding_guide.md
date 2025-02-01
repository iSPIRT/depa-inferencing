**Authors:** <br>
[Kapil Vaswani](https://github.com/kapilvgit), iSPIRT<br>
[Pavan Adukuri](https://github.com/pavanad), iSPIRT

# DEPA inferencing services onboarding and self-serve guide

This document provides guidance to data providers and consumers to onboard to [DEPA Inferencing Services][5].

Following are the steps that data providers and consumers need to follow to onboard, integrate, deploy,
test, scale and run depa inferencing services in non-production and production environments.

## Step 1: Enroll with DEPA inferencing
* Refer to the [guide][13] to enroll with DEPA inferencing and enroll using the form 
  documented [here][124]. This is a prerequisite for onboarding to DEPA inferencing.

* Onboard to DEPA inferencing and enroll with [Coordinators][37] by filling out this
  [form][125].

  _Note:_
   * _Data consumers need to choose one of the currently [supported cloud platforms][27] to run B&A services._
   * _Set up a cloud account on a preferred [cloud platform][27] that is supported._ 
   * _Provide the specific information related to their cloud account in the intake form._
   * _Data consumers can onboard more than one cloud account (e.g. Azure subscription ID, AWS account IDs or GCP service accounts) for the same enrollment site._

## Step 2: Setup for DEPA inferencing 

### Buyer

  * Develop [generateBid][29]().
  * Setup [Key/Value service][31].
  * If your Key/Value server supports filtering of interest groups, refer to this section and [metadata forwarding][25].
  * [Optimize payload][32].
  * Review [logging][26].

### Cloud platforms

  * Data consumers need to choose one of the currently [supported cloud platforms][27] to run
    DEPA inferencing services. Refer to the corresponding cloud support explainer for details:
    * [Azure support][]
      * Data consumers must setup an [Azure subscription][] and create users with appropriate privileges. 
    * [AWS support][33]
      * Adtechs must set up an [AWS account][34], create IAM users and security credentials.
    * [GCP support][35]
      * Create a GCP Project and generate a cloud service account. Refer to the [GCP project setup][36] section for more details.

## Step 3: Coordinator integration

**_Step 1 covers enrollment with Coordinators as part of onboarding to DEPA inferencing. This step
   provides further guidance around coordinator integration._**

The Coordinators run [key management systems (key services)][43] that provision keys to
DEPA inferencing services running in a [trusted execution environment (TEE)][44] after
service attestation. Integration of DEPA inferencing workloads with
Coordinators would enable TEE server attestation and allow fetching live
encryption / decryption keys from [public or private key service endpoints][43].

_Note:_
 * _Refer to [DEPA inferencing release notes][126] for the prod images allowed by Coordinators
    associated with a specific release._
 * _Data consumers can only use production images attested by the key management systems_
   _(Coordinators) in production. 
 * _Data consumers must use [Test mode](#test-mode) with debug (non-prod) images. This would
    disable attestation of TEEs._
 * _Without successfully onboarding to the Coordinator, data consumers will not be able to run_
   _attestable services in TEE and therefore will not be able to process production data_
   _using DEPA inferencing services._ 
 * _Key management systems are not in the critical path of DEPA inferencing services. The_
   _cryptographic keys are fetched from the key services in the non critical_
   _path at service startup and periodically every few hours, and cached in-memory_
   _server side._
 * _Data providers can call buyers on a different cloud platform. Data consumer clients can_
   _fetch public keys from all supported cloud platforms, this is_
   _important to encrypt request payloads for FrontEnd service._

**After onboarding to DEPA inferencing, Coordinators will provide url endpoints of key services to
the data providers and consumers. Data consumers must incorporate those in DEPA inferencing services configurations. Refer below
for more information.**

### Test mode

Test mode supports [cryptographic protection][45] with hardcoded public-private key
pairs, while disabling TEE server attestation. Adtechs can use this mode with debug / non-prod
DEPA inferencing service images for debugging and internal testing.

During initial phases of onboarding, this would allow data providers and consumers to test DEPA inferencing
server workloads even before integration with Coordinators.

### Amazon Web Services (AWS)

The data consumer should provide their AWS Account Id to both the Coordinators.

The Coordinators would create IAM roles. After data consumer provide the AWS account Id, 
they would attach that information to the IAM roles and include in an allowlist. 
Then the Coordinators would let data consumer know about the IAM roles and that should be included
in the DEPA inferencing services Terraform configs that fetch cryptographic keys from key management systems.

Data consumer must set IAM roles information provided by the Coordinators in the following parameters
in buyer or seller server configs for AWS deployment:
  * PRIMARY_COORDINATOR_ACCOUNT_IDENTITY
  * SECONDARY_COORDINATOR_ACCOUNT_IDENTITY

### Google Cloud Platform (GCP)

The data consumer should provide IAM service account email to both the Coordinators.

The Coordinators would create IAM roles. After data consumers provide their service account email,
the Coordinators would attach that information to the IAM roles and include in an allowlist. 
Then the Coordinators would let data consumer know about the IAM roles and that should be included 
in the DEPA inferencing services Terraform configs that fetch cryptographic keys from key management systems.

Data must set IAM roles information provided by the Coordinators in the following parameters
in buyer or seller server configs for GCP deployment:
  * PRIMARY_COORDINATOR_ACCOUNT_IDENTITY
  * SECONDARY_COORDINATOR_ACCOUNT_IDENTITY

## Step 4: Build, deploy services

Follow the steps only for your preferred cloud platform to build and deploy DEPA inferencing services.

### DEPA inferencing code repository

DEPA inferencing services code and configurations are open sourced to [Github repo][52].

The hashes of approved images services will be published to
the [DEPA inferencing release page][53]. 

### Deploy services 

_Note: The configurations set the default parameter values. The values that are_
_not set must be filled in by data consumers before deployment to the cloud._

#### AWS

 * Refer to understand Terraform configuration setup and layout here.
 * Refer to the [README][106] for deployment.
 * Follow the steps [here][107] to create configurations for different environments
   for deployment.
   * Data consumer: To deploy [FrontEnd (FE)][110] and [inferencing][111] server
      instances, copy paste [buyer/buyer.tf][87] and update custom values.
 * _Note: Data consumers are not required to update the default configurations before_
   _DEPA inferencing services deployment._

#### GCP

 * Refer to understand Terraform configuration setup and layout [here][112].
 * Refer to the [README][113] for deployment.
 * Follow the steps [here][114] to create configurations for different environments
   for deployment.
   * Data consumer: Deploy [FrontEnd (BFE)][110] and [Inferencing][111] server instances,
      copy paste [buyer/buyer.tf][89] and update custom values.
 * _Note: Data consumers are not required to update the [default configurations][115]_
   _before DEPA inferencing deployment._

## Step 5: Integration with clients 

## Step 6: Test

### Payload generation tool

The [secure invoke][63] tool is a payload generation tool that uses hardcoded public
keys to encrypt payloads and then sends requests to TEE-based DEPA inferencing services. The
corresponding private keys of the same version are hardcoded / configured in B&A
services such that the encrypted payloads can be correctly decrypted. Refer to
the [README][64] for more information about the tool.
 * The tool works with DEPA inferencing services running in [test mode][42].
 * The tool can also work with DEPA inferencing services when [Coordinators][65] are enabled.
   The tool has the ability to use custom live public keys for encryption that
   can be fetched from the public key service endpoint of [key management systems][43]
   running on a supported cloud platform. Refer [here][67] for more details.

#### Data consumer

 * The tool can generate [GetBidsRequest][70] payload for communication with TEE based
   FrontEnd if a plaintext request payload is supplied.
 * The tool also has the capability to decrypt the response received from TEE
   based FrontEnd and print out the out human readable plaintext response.

### Local testing

Data consumer can test the services locally. This step is optional.

Refer to the [README][71] to understand how DEPA inferencing services are built and run locally.
 * Refer here to [test buyer services][72] (BuyerFrontEnd, Bidding) locally.
 * Refer here to [test seller services][73] (SellerFrontEnd, Auction) locally.

### Functional testing

It is recommended to do function testing during the initial [onboarding phase][74].

For functional testing, B&A services must be enabled in [Test mode][42] so that
Coordinators can disabled.

There are couple of options for functional testing:
 * Option 1: Using the [secure invoke][63] tool.
   In this case, B&A services can be tested without real client (web browser,
   Android app) integration. B&A services running in [Test mode][42] can receive
   encrypted requests generated by the tool and the response from B&A services
   can be decrypted by the tool.

 * Option 2: [End to end testing][75] from Chrome browser.

## Related publications

Refer to related publications on [Github][84].

[1]: https://github.com/chatterjee-priyanka
[2]: https://github.com/dankocoj-google
[3]: https://github.com/jasarora-google
[4]: https://github.com/akundla-google
[5]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md
[6]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#timeline-and-roadmap
[7]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#high-level-design
[8]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#privacy-considerations
[9]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#security-goals
[10]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#trust-model
[11]: https://docs.google.com/forms/d/e/1FAIpQLSePSeywmcwuxLFsttajiv7NOhND1WoYtKgNJYxw_AGR8LR1Dg/viewform
[12]: https://github.com/privacysandbox/fledge-docs/issues
[13]: https://developers.google.com/privacy-sandbox/private-advertising/enrollment
[14]: #enrollwithcoordinators
[15]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#spec-for-ssp
[16]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#scoread
[17]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#reportresult
[18]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#seller-byos-keyvalue-service
[19]: https://github.com/WICG/turtledove/blob/main/FLEDGE_browser_bidding_and_auction_API.md
[20]: https://developer.android.com/design-for-safety/privacy-sandbox/protected-audience-bidding-and-auction-integration
[21]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/api/bidding_auction_servers.proto#L58
[22]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_system_design.md#sellers-ad-service
[23]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/api/bidding_auction_servers.proto#L288
[24]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/api/bidding_auction_servers.proto
[25]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#metadata-forwarding
[26]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#logging
[27]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#supported-public-cloud-platforms
[28]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#spec-for-dsp
[29]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#generatebid
[30]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#reportwin
[31]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyer-byos-keyvalue-service
[32]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding-auction-services-payload-optimization.md
[33]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_aws_guide.md
[34]: https://docs.aws.amazon.com/signin/latest/userguide/introduction-to-iam-user-sign-in-tutorial.html
[35]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md
[36]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md#gcp-project-setup
[37]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#deployment-by-coordinators
[38]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#beta-testing
[39]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#scale-testing
[40]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#fast-follow
[41]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#alpha-testing
[42]: #testmode
[43]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#key-management-systems
[44]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#trusted-execution-environment
[45]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#client--server-and-server--server-communication
[46]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/seller/seller.tf
[47]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/seller/seller.tf
[48]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#enrollment-with-aws-coordinators
[49]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#enrollment-with-gcp-coordinators
[50]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#enroll-with-coordinators
[51]: https://docs.google.com/forms/d/e/1FAIpQLSduotEEI9h_Y8uEvSGdFoL-SqHAD--NVNaX1X1UTBeCeEM-Og/viewform
[52]: https://github.com/privacysandbox/bidding-auction-servers
[53]: https://github.com/privacysandbox/bidding-auction-servers/releases
[54]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_aws_guide.md#step-0-prerequisites
[55]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md#step-0-prerequisites
[56]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/debug#running-servers-locally
[57]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_aws_guide.md#step-1-packaging
[58]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md#step-1-packaging
[59]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#browser---bidding-and-auction-services-integration
[60]: #productiontrafficexperiments 
[61]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#beta-2-february-2024
[62]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#android---bidding-and-auction-services-integration
[63]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/secure_invoke
[64]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/secure_invoke/README.md
[65]: #step3:enrollwithcoordinators
[66]: #cloudplatforms
[67]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/secure_invoke/README.md#using-custom-keys
[68]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/api/bidding_auction_servers.proto#L300
[69]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/api/bidding_auction_servers.proto#L453
[70]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/api/bidding_auction_servers.proto#L491
[71]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/debug/README.md
[72]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/debug/README.md#test-buyer-stack
[73]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/tools/debug/README.md#test-seller-stack
[74]: #non---productiontrafficexperiments
[75]: #integrationwithwebbrowser
[76]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/load_testing
[77]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/load_testing#recommended-load-testing-tool
[78]: https://chromestatus.com/feature/4649601971257344
[79]: https://developer.chrome.com/origintrials/#/view_trial/2845149064591310849
[80]: https://github.com/privacysandbox/fledge-docs/blob/main/debugging_protected_audience_api_services.md
[81]: https://github.com/privacysandbox/fledge-docs/blob/main/monitoring_protected_audience_api_services.md
[82]: https://github.com/privacysandbox/fledge-docs/blob/main/monitoring_protected_audience_api_services.md#proposed-metrics
[83]: https://github.com/WICG/protected-auction-services-discussion
[84]: https://github.com/privacysandbox/protected-auction-services-docs
[85]: #step11:determineserviceavailability
[86]: https://aws.amazon.com/about-aws/global-infrastructure/regions_az/
[87]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/buyer/buyer.tf
[88]: https://cloud.google.com/compute/docs/regions-zones
[89]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/buyer/buyer.tf
[90]: https://github.com/privacysandbox/bidding-auction-servers/tree/c346ce5a79ad853c622f64ffd5082e3d1a4457d6/production/deploy/aws/terraform/services/load_balancing
[91]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
[92]: https://aws.amazon.com/app-mesh/
[93]: https://github.com/privacysandbox/bidding-auction-servers/blob/b27547a55f20021eb91e1e61b0d2175b4aee02ea/production/deploy/gcp/terraform/services/load_balancing/main.tf
[94]: https://cloud.google.com/load-balancing/docs/https
[95]: https://en.wikipedia.org/wiki/Service_mesh
[96]: https://cloud.google.com/traffic-director
[97]: https://cloud.google.com/load-balancing/docs/backend-service#utilization_balancing_mode
[98]: https://cloud.google.com/load-balancing/docs/backend-service#:~:text=If%20the%20average,the%20load%20balancer
[99]: #utilizationmode
[100]: https://github.com/privacysandbox/bidding-auction-servers/blob/9a17ea6e12bdd0720c1a6ab3e4b4932ebd66621d/production/deploy/gcp/terraform/environment/demo/seller/seller.tf#L152
[101]: https://cloud.google.com/load-balancing/docs/backend-service#rate_balancing_mode
[102]:#step10:scalabilityandperformancetuning
[103]: https://github.com/privacysandbox/bidding-auction-servers/tree/main/tools/load_testing#wrk2
[104]: https://ghz.sh/
[105]: #ratemode
[106]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/README.md
[107]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/aws/terraform/environment/demo/README.md#using-the-demo-configuration
[108]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#sellerfrontend-service
[109]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#auction-service
[110]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyerfrontend-service
[111]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#bidding-service
[112]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_gcp_guide.md#step-2-deployment
[113]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/README.md
[114]: https://github.com/privacysandbox/bidding-auction-servers/blob/main/production/deploy/gcp/terraform/environment/demo/README.md#using-the-demo-configuration
[115]: https://github.com/privacysandbox/bidding-auction-servers/tree/b27547a55f20021eb91e1e61b0d2175b4aee02ea/production/deploy/gcp/terraform/services
[116]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_event_level_reporting.md#rationale-for-the-design-choices
[117]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_protected_app_signals.md#buyer-ba-services
[118]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_protected_app_signals.md#preparedataforadretrieval-udf
[119]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_protected_app_signals.md#generatebid-udf
[120]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_protected_app_signals.md
[121]: https://github.com/privacysandbox/protected-auction-key-value-service/blob/main/docs/tee_kv_server_overview.md
[122]: https://github.com/privacysandbox/protected-auction-key-value-service/blob/main/docs/ad_retrieval_overview.md
[123]: https://github.com/privacysandbox/protected-auction-key-value-service/blob/main/docs/protected_app_signals/ad_retrieval_overview.md#udf-api
[124]: https://developers.google.com/privacy-sandbox/private-advertising/enrollment#how_to_enroll
[125]: https://docs.google.com/forms/d/e/1FAIpQLSduotEEI9h_Y8uEvSGdFoL-SqHAD--NVNaX1X1UTBeCeEM-Og/viewform
[126]: https://github.com/privacysandbox/bidding-auction-servers/releases