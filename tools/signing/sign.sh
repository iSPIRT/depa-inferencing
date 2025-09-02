#!/bin/bash

# Script to download certificates from Azure Key Vault and sign CCF proposals
# This script is designed to work with the DEPA inferencing KMS policy update workflow

set -e  # Exit on any error

# Configuration - these should be set as environment variables or passed as arguments
AZURE_VAULT_NAME="${AZURE_VAULT_NAME:-}"
KMS_DEPLOYMENT_NAME="${KMS_DEPLOYMENT_NAME:-depa-inferencing-kms}"
PROPOSAL="${PROPOSAL:-key_release_policy.json}"

AZURE_KEY_NAME="${KMS_DEPLOYMENT_NAME}-member0"
KMS_URL="https://${KMS_DEPLOYMENT_NAME}.confidential-ledger.azure.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are available
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if jq is installed for JSON processing
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        exit 1
    fi
    
    # Check if curl is available for API calls
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Please install it first."
        exit 1
    fi
}

download_service_certificate() {
    print_status "Downloading service certificate for '$KMS_DEPLOYMENT_NAME'..."
    
    # Save the service certificate
    curl https://identity.confidential-ledger.core.azure.com/ledgerIdentity/$KMS_DEPLOYMENT_NAME \
        | jq -r '.ledgerTlsCertificate' > service_cert.pem
    export KMS_SERVICE_CERT_PATH="$(pwd)/service_cert.pem"
}

# Function to download certificate from Azure Key Vault
download_member_certificate() {    
    print_status "Downloading certificate '$AZURE_KEY_NAME' from Key Vault '$AZURE_VAULT_NAME'..."
    
    # Download the certificate
    az keyvault certificate download \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "$AZURE_KEY_NAME" \
        --file "member0_cert.pem" \
        --encoding PEM
    
    if [ $? -eq 0 ]; then
        print_success "Certificate downloaded to member0_cert.pem"
        export KMS_MEMBER_CERT_PATH="$(pwd)/member0_cert.pem"
    else
        print_error "Failed to download certificate $AZURE_KEY_NAME"
        exit 1
    fi
}

# Function to sign and submit proposal using CCF CLI
sign_and_submit_proposal() {
    set -e 

    local msg_type="proposal"
    local content="$PROPOSAL"
    local extra_args=""
    
    print_status "Signing and submitting proposal using Azure Key Vault..."
    
    # Check if proposal file exists
    if [ ! -f "$content" ]; then
        print_error "Proposal file not found: $content"
        exit 1
    fi
    
    # Get current time in ISO format
    creation_time=$(date -u +"%Y-%m-%dT%H:%M:%S")
    
    # Get bearer token for Azure Key Vault
    bearer_token=$( \
        az account get-access-token \
        --resource https://vault.azure.net \
        --query accessToken --output tsv \
    )
    
    if [ -z "$bearer_token" ]; then
        print_error "Failed to get Azure access token"
        exit 1
    fi
    
    export AKV_URL=$( \
        az keyvault key show \
        --vault-name $AZURE_VAULT_NAME \
        --name $AZURE_KEY_NAME \
        --query key.kid \
        --output tsv)

    signature=$(mktemp)
    ccf_cose_sign1_prepare \
        --ccf-gov-msg-type $msg_type \
        --ccf-gov-msg-created_at $creation_time \
        --content $content \
        --signing-cert ${KMS_MEMBER_CERT_PATH} \
        $extra_args \
        | curl -X POST -s \
            -H "Authorization: Bearer $bearer_token" \
            -H "Content-Type: application/json" \
            "${AKV_URL}/sign?api-version=7.2" \
            -d @- > $signature

    ccf_cose_sign1_finish \
        --ccf-gov-msg-type $msg_type \
        --ccf-gov-msg-created_at $creation_time \
        --content $content \
        --signing-cert ${KMS_MEMBER_CERT_PATH} \
        --signature $signature \
        $extra_args \
        | curl $KMS_URL/app/proposals \
            -H "Content-Type: application/cose" \
            -H "Authorization: Bearer $bearer_token" \
            --data-binary @- \
            --cacert $KMS_SERVICE_CERT_PATH \
            -w '\n%{http_code}\n'

    rm -rf $signature
}

# Main execution
main() {
    set -e 

    print_status "Starting CCF proposal signing process..."
    
    # Check if required environment variables are set
    if [ -z "$AZURE_VAULT_NAME" ]; then
        print_error "AZURE_VAULT_NAME environment variable is required"
        print_status "Usage: AZURE_VAULT_NAME=your-keyvault-name ./sign.sh"
        exit 1
    fi

    if [ -z "$KMS_DEPLOYMENT_NAME" ]; then
        print_error "KMS_DEPLOYMENT_NAME environment variable is required"
        print_status "Usage: KMS_DEPLOYMENT_NAME=your-kms-deployment-name ./sign.sh"
        exit 1
    fi

    if [ -z "$PROPOSAL" ]; then
        print_error "PROPOSAL environment variable is required"
        print_status "Usage: PROPOSAL=your-proposal-file ./sign.sh"
        exit 1
    fi

    # Check dependencies
    check_dependencies
        
    # Create working directory
    WORKSPACE="$(pwd)/workspace"
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE"
    
    print_status "Working directory: $WORKSPACE"
    
    # Download KMS service certificate
    download_service_certificate

    # Download member certificate
    download_member_certificate 
        
    # Sign and submit proposal 
    sign_and_submit_proposal
    
    print_success "Proposal signed and submitted!"
}

# Run main function
main "$@"
