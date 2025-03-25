# Key Management Service (KMS) Deployment Guide

**Version:** v1.17.0
**Deployment Time:** ~60 minutes
**Next Step:** [Offer Service Deployment](../offer-service/README.md)

## Quick Reference
- **Dependencies:** None (first component)
- **Required Services:** Cloud KMS, Functions, Run, Artifact Registry, IAM
- **Regions:** Primary (us-central1), Secondary (us-west3)

## Required Resources
1. Artifact Registry Repository (`your-repo-name`)
2. GCS Bucket (`your-bucket-name`)
3. Enabled APIs in GCP Project

## Deployment Steps

### 1. Repository Setup

```bash
git clone git@github.com:iSPIRT/coordinator-services-and-shared-libraries.git
cd coordinator-services-and-shared-libraries
```

### 2. Container Image Build

```bash
# Build base container
gcloud builds submit --config=build-scripts/gcp/build-container/cloudbuild.yaml \
  --substitutions=_BUILD_IMAGE_REPO_PATH="your-repo-name",_BUILD_IMAGE_NAME="bazel-build-container",_BUILD_IMAGE_TAG="latest"

# Build service containers
gcloud builds submit --config=build-scripts/gcp/cloudbuild.yaml \
  --substitutions=_BUILD_IMAGE_REPO_PATH="your-repo-name",_BUILD_IMAGE_NAME="bazel-build-container",_BUILD_IMAGE_TAG="latest",\
  _OUTPUT_IMAGE_REPO_PATH="your-repo-name",_OUTPUT_KEYGEN_IMAGE_NAME="keygen_mp_gcp_prod",\
  _OUTPUT_PUBKEYSVC_IMAGE_NAME="public-key-hosting-service",_OUTPUT_ENCKEYSVC_IMAGE_NAME="private-key-hosting-service",\
  _OUTPUT_KEYSTRSVC_IMAGE_NAME="key-storage-service",_OUTPUT_IMAGE_TAG="latest",\
  _TAR_PUBLISH_BUCKET="your-bucket",_TAR_PUBLISH_BUCKET_PATH="coordinatorv1-17"
```

### 3. Infrastructure Components
Deploy in this order:
1. Domain Records
2. Operator Groups
3. MPKHS Secondary
4. WIPP Secondary
5. MPKHS Primary
6. WIPP Primary
7. MPKHS Secondary (Redeployment)

#### Domain Record Setup

**Configuration:**
Create `$REPO_BASE/terraform/gcp/environments_mp_primary/demo/domainrecordsetup/domainrecordsetup.auto.tfvars`:
```hcl
project     = "your-gcp-project-id"
domain_name = "your-domain"  # Preferably managed by GCP domains
```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_primary/demo/domainrecordsetup
terraform init
terraform plan
terraform apply --auto-approve
```

#### Allowed Operator Group

**Prerequisites:**
- Admin privileges in Google Admin Console (admin.google.com)

**Configuration:**
Create `$REPO_BASE/terraform/gcp/environments_mp_primary/demo/allowedoperatorgroup/demo.auto.tfvars`:
```hcl
project     = "your-gcp-project-id"
domain_name = "your-domain"  # Preferably managed by GCP domains
organization_domain = "your-google-org-domain"
group_name_prefix   = "privacysandbox-op"

# Note: the list items of owners and members should be mutually exclusive.
owners  = []  <!-- Accounts of KMS Owner goes here -->
members = [] <!-- Account of operators goes here -->

```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_primary/demo/domainrecordsetup
terraform init
terraform plan
terraform apply --auto-approve
```

#### MPKHS Secondary

**Prerequisites:**
Update `$REPO_BASE/terraform/gcp/environments_mp_secondary/demo/mpkhs_secondary/demo.auto.tfvars`:
```hcl
environment = "cord-b"
project     = "your-gcp-project-id"
primary_region   = "us-central1"  # Check resource availability
secondary_region = "us-west3"     # Check resource availability

encryption_key_service_cloudfunction_memory_mb = 1024
key_storage_service_cloudfunction_memory_mb    = 1024

encryption_key_service_zip = "../../../jars/EncryptionKeyServiceHttpCloudFunctionDeploy.zip"
key_storage_service_zip    = "../../../jars/KeyStorageServiceHttpCloudFunctionDeploy.zip"

enable_domain_management   = true
parent_domain_name         = "<domain_name from domainrecordsetup>"
parent_domain_name_project = "<project_id from domainrecordsetup>"

mpkhs_package_bucket_location = "US"

spanner_instance_config  = "nam10"
spanner_processing_units = 100

# Uncomment and re-apply once primary MPKHS has been deployed.
#allowed_wip_iam_principals = ["serviceAccount:<output key_generation_service_account from mpkhs-primary in primary coordinator>"] for this we will redeploy mpkhs-secondary post we deploy mpkhs-primary  

allowed_operator_user_group = "<output allowed_operator_group_id from allowedoperatorgroup in secondary coordinator>"

assertion_tee_swname = "CONFIDENTIAL_SPACE"

assertion_tee_container_image_hash_list = ["<list of hash values for images>"]

alarms_enabled            = true
alarms_notification_email = "<email to receive alarms>"
```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_secondary/demo/mpkhs_secondary
terraform init
terraform plan
terraform apply --auto-approve
```

#### Operator WIPP (Secondary)

**Prerequisites:**
Update `$REPO_BASE/terraform/gcp/environments_mp_secondary/demo/operator_wipp/demo.auto.tfvars`:
```hcl
environment = "cord-b"
project     = "your-gcp-project-id"

key_encryption_key_id = "<output from mpkhs_secondary key_encryption_key_id>"

allowed_wip_iam_principals = ["group:<output allowed_operator_group_id from allowedoperatorgroup in secondary coordinator>"]

assertion_tee_swname = "CONFIDENTIAL_SPACE"

assertion_tee_container_image_hash_list = ["<list of hash values for images>"]
```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_secondary/demo/operator_wipp
terraform init
terraform plan
terraform apply --auto-approve
```

#### MPKHS Primary

**Prerequisites:**
Update `$REPO_BASE/terraform/gcp/environments_mp_primary/demo/mpkhs_primary/demo.auto.tfvars`:
```hcl
environment = "cord-a"
project     = "your-gcp-project-id"
primary_region   = "us-central1"  # Check resource availability
secondary_region = "us-west3"     # Check resource availability

enable_domain_management     = true
parent_domain_name          = "<domain name from domainrecordsetup>"
parent_domain_name_project  = "<project_id from domainrecordsetup>"

get_public_key_cloudfunction_memory_mb         = 1024
encryption_key_service_cloudfunction_memory_mb = 1024

get_public_key_service_zip = "../../../jars/PublicKeyServiceHttpCloudFunctionDeploy.zip"
encryption_key_service_zip = "../../../jars/EncryptionKeyServiceHttpCloudFunctionDeploy.zip"

mpkhs_package_bucket_location = "US"
spanner_instance_config = "nam10"
spanner_processing_units = 100

application_name = "protected-auction"
key_generation_tee_allowed_sa = "<output wip_allowed_service_account from mpkhs_secondary>"
key_storage_service_base_url = "<output from key_storage_base_url in secondary coordinator>"
key_storage_service_cloudfunction_url = "<output from key_storage_cloudfunction_url in secondary coordinator>"
peer_coordinator_kms_key_uri = "<output from key_encryption_key_id in secondary coordinator>"
peer_coordinator_service_account = "<output from wip_verified_service_account in secondary coordinator>"
peer_coordinator_wip_provider = "<output from workload_identity_pool_provider_name in secondary coordinator>"
allowed_operator_user_group = "<output from allowed_operator_group_id in allowedoperatorgroup in primary coordinator>"

alarms_enabled = true
alarms_notification_email = "<email to receive alarms>"
```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_primary/demo/mpkhs_primary
terraform init
terraform plan
terraform apply --auto-approve
```

#### Operator WIPP (Primary)

**Prerequisites:**
Update `$REPO_BASE/terraform/gcp/environments_mp_primary/demo/operator_wipp/demo.auto.tfvars`:
```hcl
environment = "cord-a"
project     = "your-gcp-project-id"
key_encryption_key_id = "<output from mpkhs_primary key_encryption_key_id>"
allowed_wip_iam_principals = ["group:<output allowed_operator_group_id from allowedoperatorgroup in primary coordinator>"]
assertion_tee_swname = "CONFIDENTIAL_SPACE"
assertion_tee_container_image_hash_list = []
```

**Deploy:**
```bash
cd $REPO_BASE/terraform/gcp/environments_mp_primary/demo/operator_wipp
terraform init
terraform plan
terraform apply --auto-approve
```

**Final Step:**
Redeploy MPKHS-secondary with the `key_generation_service_account` value from MPKHS-primary as documented above.