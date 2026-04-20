# All user-facing deployment values are set in terraform.tfvars (see that file).
# Defaults here match the previous in-root-module locals for optional tuning.

variable "gcp_project_id" {
  description = "GCP project id used for providers and resources."
  type        = string
}

variable "environment" {
  description = "Primary buyer environment key (must be <= 10 characters)."
  type        = string
  validation {
    condition     = length(var.environment) <= 10
    error_message = "Due to current naming scheme limitations, environment must not be longer than 10."
  }
}

variable "image_repo" {
  description = "Container registry + path prefix (no trailing slash), e.g. REGION-docker.pkg.dev/PROJECT/repo."
  type        = string
}

variable "buyer_operator" {
  description = "Operator name used to tag resources."
  type        = string
}

variable "image_tag" {
  description = "Image tag for the default traffic arm (bidding_service and buyer_frontend_service)."
  type        = string
}

variable "traffic_weight" {
  description = "Traffic weight for the default arm (0-1000; primary arm should be > 0)."
  type        = number
  default     = 1000
}

variable "header_experiment_image_tag" {
  description = "Image tag for the header-routing experiment arm; leave \"\" to use image_tag."
  type        = string
  default     = ""
}

variable "header_experiment_match_rules" {
  description = "Header match rules for the experiment arm (see frontend_load_balancing module). Empty disables the experiment instance."
  type = list(object({
    header_name   = string
    exact_match   = string
    prefix_match  = string
    present_match = bool
  }))
  default = []
}

variable "buyer_runtime_flag_override" {
  description = "Merged into runtime flags for both default and experiment arms (string map)."
  type        = map(string)
  default     = {}
}

variable "default_region_config" {
  description = "Per-region autoscaling configuration passed through to the buyer module."
  type        = any
  default = {
    "us-central1" = {
      collector = {
        machine_type          = "e2-micro"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
      }
      backend = {
        machine_type          = "n2d-standard-2"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
        use_intel_amx         = false
      }
      frontend = {
        machine_type          = "n2d-standard-2"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
      }
    }
  }
}

variable "frontend_domain_ssl_certificate_id" {
  description = "SSL certificate resource id for the frontend, if not using certificate maps."
  type        = string
  default     = ""
}

variable "frontend_certificate_map_id" {
  description = "Certificate Manager map id, e.g. //certificatemanager.googleapis.com/projects/<id>/locations/global/certificateMaps/<name>"
  type        = string
}

variable "frontend_ssl_policy_id" {
  description = "Optional SSL policy id for the HTTPS proxy."
  type        = string
  default     = ""
}

variable "buyer_domain_name" {
  description = "Public DNS name for the buyer frontend load balancer."
  type        = string
}

variable "frontend_dns_zone" {
  description = "Google Cloud DNS managed zone name for buyer_domain_name."
  type        = string
}

variable "service_account_email" {
  description = "Service account email used by Confidential Space / MIG instances."
  type        = string
}

variable "vm_startup_delay_seconds" {
  description = "Time allowed for instances to pass health checks after boot."
  type        = number
  default     = 200
}

variable "cpu_utilization_percent" {
  description = "Target CPU utilization (0-1) for autoscaling."
  type        = number
  default     = 0.6
}

variable "use_confidential_space_debug_image" {
  description = "If true, use the Confidential Space debug base image (SSH allowed)."
  type        = bool
  default     = true
}

variable "tee_impersonate_service_accounts" {
  description = "Comma-separated emails for TEE service account impersonation."
  type        = string
}

variable "test_mode" {
  description = "Buyer frontend / coordinator test mode (string \"true\" or \"false\" for runtime_flags)."
  type        = string
  default     = "true"
}

variable "buyer_code_bucket" {
  description = "GCS bucket name for protected auction bidding JS (BUYER_CODE_FETCH_CONFIG)."
  type        = string
}

variable "buyer_code_blob" {
  description = "Object name in buyer_code_bucket for the default bidding JS blob."
  type        = string
  default     = "generateBid.js"
}

variable "consented_debug_token" {
  description = "CONSENTED_DEBUG_TOKEN runtime flag."
  type        = string
  default     = "test_token"
  sensitive   = true
}
