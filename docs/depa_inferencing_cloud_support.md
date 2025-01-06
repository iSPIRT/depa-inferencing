
# Public Cloud Support

DEPA inferencing supports real-time sharing and processing of sensitive data in a way that protects privacy of consumers. To meet such goals, DEPA inferencing requires that inferencing be done in an attested and isolated environment (also referred to as Trusted Execution Environment, or TEE), using software provided and approved for this purpose by DEPA inferencing. 

In this document, we describe the requirements that TEEs must satisfy in order to host DEPA inferencing, and describe the TEE platforms in Azure, GCP and AWS that meet these requirements. Support in multiple clouds is critical for many organizations to meet regulatory requirements around business continuity. 

## TEE Requirements

TEEs must satisfy the following requirements to be eligible for running trusted DEPA inferencing workloads:

*   The environment must be secure, private, and isolated. The CSP must implement controls to prevent all parties (including the workload Operator, and agents or employees of the CSP) from:
    *   Viewing, adding, removing or altering data while it is in use within the TEE (referred to as Data Confidentiality and Data Integrity)
    *   Adding, removing, or altering code executing in the TEE (referred to as Code Integrity)
    *   Otherwise tampering or interacting with the workload (except via APIs explicitly exposed by the workload)
*   The environment must be remotely attestable. This means that the CSP must provide an attestation report with claims about the state of the TEE, including:

    *   Whether the workload meets the above requirements that the environment is secure, private, and isolated
    *   Cryptographic measurements of the workload and any security-relevant software components running in the TEE
    *   Identity of the operator 

    The above claims must be exposed via a secure API, which is accessible to an external Relying Party (such as a KMS) when evaluating whether the instance can be trusted with credentials such as decryption keys. Additional information about the role of KMS is available in our service-specific explainers: [Key Management Systems](https://github.com/ispirt/depa-inferencing/protected-auction-services-docs/blob/main/trusted_services_overview.md). 

*   The TEE must be commercially available to a wide range of customers, including academic and security researchers. 
*   The TEE must be able to run a Linux-based containerized workload with access to functionality such as networking, load balancing, and object storage.

## Public Cloud TEEs
DEPA inferencing will support deployments on Azure, GCP and AWS using the following commercially available TEE platforms that meet the above requirements. 

### Azure 
Azure provides a commercially available Cloud TEE solution using [confidential containers on Azure Container Instances](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-confidential-overview). Confidential containers on Azure Container Instances provide secure, private and isolated environments, which helps prevent the operator and CSP from accessing customer data. Azure further provides a hardware-based [attestation](https://learn.microsoft.com/en-us/azure/container-instances/confidential-containers-attestation-concepts) process for these environments that includes all application containers and their configuration. Confidential containers on Azure Container Instances can run Linux-based containerized workloads.

The confidential containers on Azure Container Instances security model is [documented](https://arxiv.org/abs/2302.03976).


### AWS
AWS provides a commercially available Cloud TEE solution using [AWS Nitro Enclave](https://aws.amazon.com/ec2/nitro/nitro-enclaves/). Nitro Enclaves provide secure, private and isolated environments, which the operator and CSP cannot access. AWS provides a cryptographic attestation service for the Nitro enclave. Nitro Enclaves can run Linux-based containerized workloads.

The AWS security model for Nitro Enclave is [documented](https://docs.aws.amazon.com/enclaves/latest/user/security.html#enclaves-security) directly, and is part of the broader Nitro system. The security model is also partially supported by an independent [security report](https://research.nccgroup.com/2023/05/03/public-report-aws-nitro-system-api-security-claims/). 

### GCP
GCP provides a commercially available Cloud TEE solution using [Confidential Space](https://cloud.google.com/security/products/confidential-computing), built on top of the Confidential VM product. Confidential Space provides secure, private and isolated environments, which the operator and CSP cannot access. GCP further provides an [Attestation process](https://cloud.google.com/docs/security/confidential-space#attestation-process) for the environments. Confidential Space can run Linux-based containerized workloads.

The Confidential Space security model is [documented](https://cloud.google.com/docs/security/confidential-space), and partially supported by an independent [security report](https://research.nccgroup.com/2022/12/06/public-report-confidential-space-security-review/).