# GCP Deployment Guide for Privacy Sandbox Buyer Stack

## Component Versions and Dependencies
```
    A[KMS Service v1.17.0] --> B[Offer Service v1.0.0]
    B --> C[Key-Value Service v2.0.0]
```

## Prerequisites

### Required Tools

- Linux-based operating system
- Google Cloud SDK (`gcloud`)
- Terraform (>= 5.37.0)
- Bazel

### Authentication

Ensure you are logged into `gcloud` with appropriate permissions.

## Deployment Flow

### 1. Key Management Service (KMS)
- [KMS Deployment Guide](key-management-service/README.md)
- Deployment time: ~60 minutes

### 2. Offer and Bidding Services
- [Offer Service Guide](offer-service/README.md)
- Deployment time: ~120 minutes

### 3. Key-Value Service (Optional)
- [Key-Value Service Guide](key-value-service/README.md)

**Note:**
* Configuration output from KMS will be used in both offer and bidding service and key-value service
* Network configuration output from offer and bidding service will be used in key-value-service

