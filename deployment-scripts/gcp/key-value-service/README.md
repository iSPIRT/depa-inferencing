# Key Value Service Deployment Guide for GCP

## Prerequisites
1. KMS deployment completed
2. Offer and Bidding Service deployment completed
3. Access to required repositories
4. Required tools:
   - Google Cloud SDK
   - Terraform
   - OpenSSL (for TLS certificate generation)

## Setup Steps

### 1. Clone Repository
```bash
git clone https://github.com/privacysandbox/protected-auction-key-value-service.git
cd protected-auction-key-value-service
```

> For detailed information, see: `$REPO_BASE/docs/deployment/deploying_on_gcp.md`

### 2. Build and Package
```bash
# Build the service
./production/packaging/gcp/build_and_test

# Push to GCP repository
./production/packaging/gcp/docker_push_gcp_repo \
  --gcp-image-repo "your-repo-name" \
  --gcp-image-tag "npd"
```

### 3. Configure Deployment

#### A. Backend Configuration
Update `$REPO_BASE/production/terraform/gcp/environments/demo/us-east1.backend.conf` with your Terraform backend settings.

#### B. TLS Configuration
1. Generate RSA key pair ([OpenSSL Guide](https://stackoverflow.com/questions/44474516/how-to-create-public-and-private-key-with-openssl))
2. Create `$REPO_BASE/production/terraform/gcp/environments/demo/secrets.auto.tfvars.json`:
```json
{
    "tls_cert": "your-certificate",
    "tls_key": "your-private-key"
}
```

#### C. Service Configuration
Create `$REPO_BASE/production/terraform/gcp/environments/demo/us-east1.tfvars.json`:
```json
{
  "existing_vpc_id": "{VPC created while deploying offer and bidding}",
  "existing_service_mesh": "{service mesh created while deploying offer and bidding}",
  "use_existing_vpc": true,
  "use_existing_service_mesh": true,
  "regions": ["us-central1"],
  "regions_cidr_blocks": ["10.0.3.0/24"],
  "regions_use_existing_nat": ["us-central1"],
  "service_mesh_address": "xds:///kv-service-host",

  "project_id": "your-project-id",
  "environment": "npd",
  "gcp_image_repo": "{your-repo}/key-value-store",
  "gcp_image_tag": "npd",
  "service_account_email": "{service account created during offer and bidding deployment}",

  "machine_type": "n2d-standard-4",
  "min_replicas_per_service_region": 1,
  "max_replicas_per_service_region": 5,
  "cpu_utilization_percent": 0.9,
  "kv_service_port": 50051,
  "envoy_port": 51052,

  "server_dns_zone": "your-server-dns-zone-name",
  "server_url": "your-kv-server-url",
  "server_domain_ssl_certificate_id": "{id of certificate for your domain}",
  "collector_dns_zone": "your-dns-zone-name",
  "collector_domain_name": "your-domain-name",

  "primary_coordinator_account_identity": "{wip_verified_service_account from operator_wipp primary}",
  "primary_coordinator_private_key_endpoint": "{encryption_key_base_url from mpkhs primary}/v1alpha/encryptionKeys",
  "primary_coordinator_region": "{gcp region for primary}",
  "primary_key_service_cloud_function_url": "{encryption_key_service_cloudfunction_url from mpkhs primary}",
  "primary_workload_identity_pool_provider": "{workload_identity_pool_provider_name from operator_wipp primary}",
  "public_key_endpoint": "{public_key_base_url from mpkhs primary}/.well-known/protected-auction/v1/public-keys",
  
  "secondary_coordinator_account_identity": "{encryption_key_service_cloudfunction_url from mpkhs secondary}",
  "secondary_coordinator_private_key_endpoint": "{encryption_key_base_url from mpkhs secondary}/v1alpha/encryptionKeys",
  "secondary_coordinator_region": "us-central1",
  "secondary_key_service_cloud_function_url": "{encryption_key_service_cloudfunction_url from mpkhs secondary}",
  "secondary_workload_identity_pool_provider": "{workload_identity_pool_provider_name from operator_wipp secondary}",

  "tee_impersonate_service_accounts": "{wip_verified_service_account from operator_wipp secondary},{wip_verified_service_account from operator_wipp secondary}",
  "use_real_coordinators": true,
  "data_bucket_id": "your-delta-file-bucket",
  "data_loading_file_format": "riegeli",

  "add_chaff_sharding_clusters": true,
  "add_missing_keys_v1": true,
  "route_v1_to_v2": true,
  "enable_external_traffic": true,
  "instance_template_waits_for_instances": true,
  "use_confidential_space_debug_image": false,
  "use_external_metrics_collector_endpoint": true,

  "data_loading_num_threads": 16,
  "realtime_updater_num_threads": 1,
  "udf_num_workers": 2,
  "vm_startup_delay_seconds": 200,
  
  "telemetry_config": "mode: EXPERIMENT",
  "metrics_export_interval_millis": 30000,
  "metrics_export_timeout_millis": 5000
}
```

### 4. Deploy

```bash
cd $REPO_BASE/production/terraform/gcp/environments/demo

# Initialize Terraform
terraform init \
  --backend-config=demo/us-east1.backend.conf \
  --var-file=demo/us-east1.tfvars.json \
  --var-file=demo/secrets.auto.tfvars.json \
  --reconfigure

# Plan deployment
terraform plan \
  --var-file=demo/us-east1.tfvars.json \
  --var-file=demo/secrets.auto.tfvars.json

# Apply deployment
terraform apply \
  --var-file=demo/us-east1.tfvars.json \
  --var-file=demo/secrets.auto.tfvars.json
