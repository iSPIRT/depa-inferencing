**Authors:** <br>
[Kapil Vaswani](https://github.com/kapilvgit), iSPIRT<br>
[Pavan Adukuri](https://github.com/pavanad), iSPIRT

# DEPA inferencing
DEPA inferencing enables sharing of sensitive data between data providers and consumers with verifiable privacy. In DEPA inferencing, sensitive data stays encrypted at all times (at rest, in transit, and during use). Data is processed only within [trusted execution environment][1] (TEE) based servers on a [supported cloud platform][6]. 

This explainer describes the system design of DEPA inferencing.

## Overview 

![Architecture diagram.](images/depa_inferencing_system_overview.png)

When a data principal visits the data provider's web application (in browser) or phone application (e.g., in android), data provider's code in the application sends HTTPS request to the data consumer's service endpoint. The request includes encrypted data pertaining to the data principal. The service endpoint is typically an application gateway, which terminates TLS requests and forwards the HTTP request to a TEE based [Frontend service][12]. The Frontend service decrypts encrypted data using decryption keys prefetched from [Key Management Service][13]. Then Frontend service looks up real-time bidding inferencing from [data consumer's key/value service][16] and calls TEE based [inferencing service][15]. After inferencing response is are received, the frontend service returns an encrypted response to the data consumer's service, which sends the encrypted response back to the client. 

DEPA inferencing services are based on the gRPC framework. The server code is developed in C++ and configurations are based on [Terraform][19]. The server code and configurations will be open sourced by iSPIRT.

DEPA inferencing services also allows execution of data consumer owned code for inferencing. The hosting environment would protect the confidentiality of the data consumer code.

The communication between services in the [DEPA inferencing system][4] is protected by TLS / SSL and additionally, request-response payloads are encrypted by [Hybrid Public Key Encryption][20] (HPKE). Also, request/response payload sent over the wire will be compressed by gzip.

## Design
  
### Data consumer
Following services will be operated by the data consumer.

#### Frontend service
The front-end service of the system that runs in the [TEE][5] on a supported cloud platform. The service is based on the gRPC framework and provides a gRPC endpoint [GetBids][32] that receives requests . 

* Frontend service instance loads configured data in memory at server start-up. This includes the following, for more details [refer here][33]:
  * Domain address of other services that Inferencing FrontEnd depends on. This includes address of buyer's key/value service, address of inferencing service and address of key hosting service in [Key Management System][13].
    
* At server start-up, the gRPC or HTTP connections to other services (inferencing service, data consumer's key/value service, cryptographic key hosting services) are prewarmed.
  
* The FrontEnd service receives GetBids request from clients.
  
* The FrontEnd service decrypts GetBids request using decryption keys prefetched from Key Management System.
  
* The FrontEnd service fetches real-time inferencing signals from the data consumer's key/value service; this is required for generating inferencing responses. The inferencing_signal_keys in different interest groups are batched for the lookup. 
  * The inferencing signal response from key/value service is split by inferencing_signal_keys in interest groups.
    
* The frontend service sends a GenerateBids request to the inferencing service. The inferencing service returns ad candidates with bid(s) for each interest group.
  
* The frontend returns all bids ([AdWithBid][35]) to the client.

#### Inferencing service
The inferencing service runs in the TEE on a supported cloud platform. In the current implementation designed for advertising scenarios, the service is based on the gRPC framework and provides an endpoint [GenerateBids][34]. It receives requests from frontend service to initiate the inferencing flow. This service responds to requests from the frontend service and has limited outbound access over the public network. 

Inferencing service allows data consumer owned code modules containing inferencing models to execute in a custom code execution engine within the TEE. The custom code execution engine is based on V8 sandbox and has tighter security restrictions; the sandbox can not log information and doesn't have disk or network access. 

* Inferencing server instances load configured data in memory at server startup. This includes the endpoint from where data consumer's code modules are prefetched and address of key management service; for more details [refer here][36].
  
* Server instances prefetch [code blobs][29] owned by data consumers from a cloud storage instance at server startup and periodically. The code modules are cached in memory by the custom code execution sandbox.
    
* Frontend service sends GenerateBids request to inferencing service for generating bids. The request payload includes interest groups, per buyer signals, real time bidding signals and other required data.
  
* For privacy, inferencing service deserializes and splits bidding signals such that GenerateBid() can only ingest bidding signals required to generate bid(s) per Interest Group.
  
* Within the Bidding service, a request is dispatched to a custom code execution engine / sandbox with all inputs required for data consumer's code execution. 
  * Within the sandbox, the data consumer's GenerateBid() code is executed within a separate worker thread for generating bids for an Interest Group. The execution within worker threads can happen in parallel. Refer to the [Adtech code execution][30] section for more details.

#### Data consumer's key/value Service
A data consumer's Key/Value service receives requests from the [Frontend service][14] and returns real-time buyer data required for inferencing, corresponding to lookup keys. The Key/Value service is also hosted within TEEs. 

## Cryptographic protocol & key fetching
The cryptographic protocol is bidirectional [Hybrid Public Key Encryption][13](HPKE). In this mechanism, public key and private key pairs are versioned. The private keys have sufficiently longer validity than public keys for the same version. Public keys are fetched from public key hosting service and private keys are fetched from private key hosting services in [Key Management Systems][20]. 

### Key fetching in client 
Client (browser, android) periodically fetches a set of public keys from the public key hosting service in Key Management Systems every 7 days and may be cached client-side with a fixed TTL in order of days. Clients should pre-fetch new versions of public keys before the expiration time of the previous set of keys. 

### Key fetching in server
Server instances running in TEE prefetch all valid private keys from the Key Management System at service startup and periodically in the non critical path. The private keys are cached in-memory and have a caching TTL in order of hours; therefore these keys are refreshed periodically every few hours. This ensures if any private key is compromised for some reason,
that is not in-use for long. Private keys are granted to the TEE based servers only after attestation. The binary hash of the service and guest operating system running on the virtual machine is validated against a hash of the open source image through attestation; note that the attestation mechanism is cloud platform specific. The server instances also prefetch a set of public keys every 7 days and cache in-memory for days. Public keys are required for encryption of outgoing requests to other TEE based servers. 

### Client to server communication
Client to server communication is protected by TLS over the untrusted public network and the [_ProtectedAudienceInput_][11] is encrypted by [Oblivious HTTP][39] which is a wrapper over bidirectional Hybrid Public Key Encryption(HPKE). The _ProtectedAudienceInput_ payload is separately encrypted because the TLS session terminates at the load balancer of front end services in B&A. The client encrypts the _ProtectedAudienceInput_ payload with a public key and the key version is prefixed in the ciphertext with Oblivious HTTP.

### Server to server communication
Server to server communication over a public unsecured network is protected by TLS and request-response payload encryption is based on bidirectional [Hybrid Public Key Encryption][13] (HPKE). Depending on the network topology of services that would communicate over a private network, request-response payload encryption may be sufficient protection. For TEE to TEE encryption, the client server would encrypt the request payload with a public key and send the key version separately along with the request ciphertext.
  
### Request-response encryption and decryption
* Request payload will be encrypted using a public key.
  * The key version will be prefixed in the request ciphertext with [Oblivious HTTP][39]. 
  * The key version will be sent separately along with the ciphertext with bidirectional [HPKE][13].
* In a TEE based server, client requests will be decrypted using split private keys.
  * The private keys must be of the same version as the public key used for encryption.
* Response will be encrypted using bidirectional HPKE, using key material from HPKE context
  of the request. 
  * The HPKE context is used to export a secret key material.

## Data consumer Code Execution Engine 
### Roma

The data consumer code execution engine is called [Roma][40] that provides a sandbox environment for untrusted, closed source, self contained code. Roma provides two backend engines for execution - 
1. [V8][41], Google's open source high-performance JavaScript & WebAssembly engine written in C++. 
2. [Bring-Your-Own-Binary][51], for executing standalone binaries compiled from languages such as C/C++ and Go. ROMA BYOB uses a single instance of a double-sandboxed Virtual Machine Monitor (VMM) called [gVisor][52]. This mode is currently only supported for the Bidding service right now.

The inferencing service that executes data consumer code, have a dependency on Roma. The frontend service do not have a dependency on Roma. The backend mode for inferencing server can be specified as a start up configuration. 

Roma is based on a multiprocessing model. When the inferencing starts up, a Roma dispatcher process is initialized that forks child processes; each child process forks processes to spawn the workers. The workers are prewarmed at server startup and remain alive to process workloads. 

For the V8 backend, there is IPC (inter process communication) between the gRPC server handler and dispatcher to dispatch requests for code execution in workers. There is also an IPC channel between dispatcher and workers. The BYOB execution mechanism is explained [here][51].

For privacy, it is important to ensure that there is isolation of workers. This means that workers will not share any memory with each other.

For reliability of the system, it is important to ensure the following:
* In case a request causes a crash, that would be failed gracefully without disrupting inference service.
* In case a worker crashes, resources will be freed up and the service will not be disrupted.
  * In a very rare event, if the dispatcher process crashes, the service will be restarted.

#### Roma workers
Following is the flow for spawning Roma workers:
* When the dispatcher process starts, that allocates all shared memory segments.
* The dispatcher forks an intermediate child process that deallocates all shared
  memory segments, except the memory segment for the target Roma worker. 
* The intermediate child process forks a target Roma worker. 
* The target Roma worker re-parent to dispatcher and the intermediate child process exits.
* If a worker crashes or the process exits, the dispatcher is notified to clean up
  resources. New worker is re-forked.
  
There is a shared memory block between the dispatcher and each worker. This would help
avoid data copies and input / output delays and that is important for a low latency
system. Inside the shared memory block, each worker has a message queue for reading
requests and writing responses. Each queue element contains both request and response.
For incoming requests, the dispatcher picks a worker queue that has the least number
of pending requests to put the new item (request) to the back of the queue. However,
the dispatcher follows a round robin placement policy when worker queues have the
same number of pending requests. The processed requests are retrieved from the front
of the queue. Each worker picks pending items from front to the back of the queue,
processes them and marks complete.

The number of workers is configurable, but by default is set to the number of
vCPU (virtual Central Processing Unit) of the virtual machine where the
Bidding / Auction gRPC application is hosted. The per worker memory limit is also
configurable. Each worker's resource usage is controlled using Linux kernel control
groups.

### Security guarantees
* Data consumer code executing in Roma or the sandbox code, will not have outbound network access from the sandbox.
* Inferencing services that depend on Roma, will have limited outbound access.
  * These services can fetch cryptographic keys from Key Management Systems that are part of the trust circle.
  * These services can respond to TEE based frontend services in B&A.
  * These services can fetch code blobs from cloud storage buckets.
* Input / output (logging, disk or file access) will be disabled within the Roma sandbox.
* Memory core dump will be disabled in Roma to prevent sensitive data leak.
* Roma will protect the confidentiality of the data consumer code and signals during the server side execution in a trusted environment. 
* Any potential vulnerability (like v8 vulnerability) may cause the data consumer code to escape the isolated worker. To mitigate this, the worker is further restricted with Linux kernel partition, resource isolation and security mechanisms (i.e. Linux namespaces, control groups and secure computing mode).
  
### Code properties
Following are the properties of code executed in Roma.

* Code is data consumer owned, not open-source.
* Code is not encrypted.
* The code is self contained and will be executed within an isolated worker thread.
  * The output of the code can only be part of the encrypted response sent to frontend
    services.
* The code blob size can vary per data consumer. 
* For V8 backend - The code can be in Javascript or WASM instantiated with Javascript. 
  * Most languages like Java, C++, C# can be compiled to WASM bytecode.
* For BYOB backend - The code can be a standalone binary built from C/C++ and Go.
    
### Code Execution
The code modules are fetched by the inferencing service in the non-request path, then dispatched to Roma along with the code version (in case of multiple code versions). The code is cached in Roma. In the request path, the code is executed in a Roma worker in isolation. The code is executed in parallel in different Roma workers. There is no state saved between two executions in the same worker. There is no shared memory resource between executions in different workers.

**Every worker has its own copy of code. However, the number of copies of code at any point is bound by the number of Roma workers in inferencing service**.

Following modes of code execution are supported:

#### Javascript Execution
Javascript can be executed in a Roma worker with the V8 backend. The Javscript code will be prefetched by Bidding / Auction
service at server startup and periodically in the non critical path.

Javascript code is preloaded, cached, interpreted and a snapshot is created. A new context is created from the snapshot before execution in a Roma worker.

#### Javascript + WASM Execution
WASM bytecode can be executed in a Roma worker along with Javascript with the V8 backend. The Javscript and WASM binary will
be prefetched by Bidding / Auction service at server startup and periodically in the non critical path. The WASM binary must be delivered with an application/wasm MIME type (Multipurpose Internet Mail Extensions).

When Javascript and WASM are provided for an execution, it is recommended that the data consumer inline WASM in the Javascript code. However, if the WASM code is not inlined, inferencing service would take care of that with a Javascript wrapper that inlines the WASM.

Javascript code is preloaded, cached, interpreted and a snapshot is created. The WASM is not included in the Javascript snapshot.

The [WASM module][42] will be instantiated synchronously using [WebAssembly.Instance][43]. A WebAssembly.Instance object is a stateful, executable instance of a WASM module that contains all the [Exported WebAssembly functions][44] that allow invoking WebAssembly code from JavaScript. 

#### WASM Execution
In this case, no Javascript is required.

WASM bytecode can be executed in a Roma worker with the V8 backend. The WASM binary will be prefetched by inferencing at server startup and periodically in the non critical path. The WASM binary must be delivered with
an application/wasm MIME type.

The WASM module is preloaded and cached in Roma in the non request path. WASM is parsed for every execution
within a Roma worker. 

#### Binary Execution
A standalone binary compiled as per [specifications][55] from languages such as C/C++ and Go can be executed in a Roma worker with the BYOB backend. The binary will be prefetched by inferencing service at server startup and periodically in the non critical path. The binary must be developed as per the [specifications][53] for receiving input and providing output ([Example][54]). 
  
### Execution in inferencing service

[GenerateBid()][45] will be executed per interest group in parallel and in isolation. For every [GenerateBids][34] request, a dispatch request is sent to Roma that batches all the inputs. Roma will execute pre-initialized GenerateBid() per interest group in separate worker processes in parallel.

### Code blob fetch and code version
#### Overview
Data consumer will need to provide code modules for inferencing. The inferencing service will prefetch code modules in the
non-request path periodically from Azure Blob Container, AWS S3 and GCP GCS buckets, configured by data consumer. The code modules will be loaded in Roma and cached. 

#### Lifecycle of the code storage bucket 
The following is an overview of the lifecycle of a bucket update. The inferencing service queries the bucket for its objects (code modules) and then updates Roma with code module additions and code module deletions.

#### Code module fetch
The code modules can be prefetched from arbitrary endpoints provided by the data consumer. The url endpoints must be configured in inferencing server configuration. If a data consumer requires both Javascript and WASM, they must provide two different url endpoints that will be set in inferencing service configuration. The inferencing services would prefetch data consumer code modules at server startup and periodically every few hours.*

#### Code version flow
* Data consumers can store multiple versions of code modules in Cloud Storage.
* Data consumers can pass the code version used by code modules in the [SelectAd][24] request.
  * Buyers can return the code version used by code module for the request
* Bidding / Auction service fetches code objects from the Cloud Storage instance (bucket)
  at service startup and periodically fetches the code objects every n hours.
* Roma dispatcher API would expose a Load() to accept a code object along with
  _code_version_id_.
* In non critical path:
  * Every n hrs, the service compares the list of current object names (code versions)
    in the bucket to what it has loaded into Roma.
  * Based on the difference, the service adds new code objects to Roma and evicts
    non-existent objects from Roma.
  * In their request, the adtech may specify the code version (object name such as v1, v2
    and so on). Roma will be able to service parallel requests specifying different code
    versions.
* In the request path, grpc service would dispatch the workload with inputs required for
  execution of cached code. 
* For Bidding / Auction services crashes / loses state, the latest code can be fetched
  when the service restarts.
  
## Concurrency
The concurrency model is based on asynchronous thread pool and callbacks. The thread pool
library is based on [EventEngine][49]. The Input / Output (IO) processing model is asynchronous IO.


[1]: https://github.com/chatterjee-priyanka
[2]: https://github.com/dankocoj-google
[3]: https://github.com/akundla-google
[4]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md
[5]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#trusted-execution-environment
[6]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#supported-public-cloud-platforms
[7]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#unified-contextual-and-fledge-auction-flow-with-bidding-and-auction-services
[8]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#specifications-for-adtechs
[9]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#service-apis
[10]: https://github.com/WICG/turtledove/blob/main/FLEDGE_browser_bidding_and_auction_API.md
[11]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#protectedaudienceinput
[12]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#sellerfrontend-service
[13]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#key-management-systems
[14]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyerfrontend-service
[15]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#bidding-service
[16]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyers-keyvalue-service
[17]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#auction-service
[18]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#sellers-keyvalue-service
[19]: https://www.terraform.io/
[20]: https://datatracker.ietf.org/doc/rfc9180/
[21]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#metadata-for-filtering-in-buyer-keyvalue-service
[22]: https://www.envoyproxy.io/
[23]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#auctionresult
[24]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#sellerfrontend-service-and-api-endpoints
[25]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#sellerfrontend-service-1
[26]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#auction-service-and-api-endpoints
[27]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[28]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#auction-service-1
[29]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#adtech-code
[30]: #adtech-code-execution-engine
[31]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#alpha-testing
[32]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyerfrontend-service-and-api-endpoints
[33]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#buyerfrontend-service-1
[34]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#bidding-service-and-api-endpoints
[35]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#adwithbid
[36]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#bidding-service-1
[37]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#deployment-by-coordinators
[38]: https://github.com/privacysandbox/fledge-docs/blob/main/trusted_services_overview.md#system-overview
[39]: https://datatracker.ietf.org/wg/ohttp/about/
[40]: https://github.com/privacysandbox/control-plane-shared-libraries/tree/main/cc/roma
[41]: https://v8.dev/
[42]: https://developer.mozilla.org/en-US/docs/WebAssembly/JavaScript_interface/Module
[43]: https://developer.mozilla.org/en-US/docs/WebAssembly/JavaScript_interface/Instance
[44]: https://developer.mozilla.org/en-US/docs/WebAssembly/Exported_functions
[45]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#generatebid
[46]: https://github.com/privacysandbox/fledge-docs/blob/main/bidding_auction_services_api.md#scoread
[47]: https://aws.amazon.com/what-is/pub-sub-messaging/
[48]: https://cloud.google.com/pubsub
[49]: https://grpc.github.io/grpc/core/classgrpc__event__engine_1_1experimental_1_1_event_engine.html
[50]: https://developers.google.com/privacy-sandbox/relevance/protected-audience/android/bidding-and-auction-services
[51]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/roma_bring_your_own_binary.md
[52]: https://gvisor.dev/
[53]: https://github.com/privacysandbox/data-plane-shared-libraries/blob/619fc5d4b6383422e54a3624d49a574e56313bc8/docs/roma/byob/sdk/docs/udf/Communication%20Interface.md
[54]: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/roma_bring_your_own_binary.md#example
[55]: https://github.com/privacysandbox/data-plane-shared-libraries/blob/619fc5d4b6383422e54a3624d49a574e56313bc8/docs/roma/byob/sdk/docs/udf/Execution%20Environment%20and%20Interface.

