variable "acme_contact" {
  type        = string
  description = "Let's Encrypt contact email address (used when generating a certificate for an FQDN)."
  default     = ""
}

variable "netbird_domain" {
  type        = string
  description = "Full FQDN where NetBird is served (e.g. vpn.example.com)."

  validation {
    condition     = length(trimspace(var.netbird_domain)) > 0
    error_message = "netbird_domain must not be empty."
  }
}

variable "netbird_owner_email" {
  type        = string
  description = "Email of the first NetBird owner user. Used only for the one-time /api/setup bootstrap. Defaults to admin@crczp"
  default     = null
}

variable "netbird_owner_name" {
  type        = string
  description = "Display name of the first NetBird owner user (one-time bootstrap)."
  default     = "CRCZP Admin"
}

variable "netbird_pat_secret_namespace" {
  type        = string
  description = "Namespace where the PAT rotation-store Secret is created and read from. Defaults to the netbird namespace. If set to another namespace, that namespace must already exist."
  default     = null
}

variable "netbird_pat_expiration_days" {
  type        = number
  description = "Lifetime in days of the generated Personal Access Token (1-365)."
  default     = 365

  validation {
    condition     = var.netbird_pat_expiration_days >= 1 && var.netbird_pat_expiration_days <= 365
    error_message = "netbird_pat_expiration_days must be between 1 and 365."
  }
}

variable "netbird_pat_rotation_schedule" {
  type        = string
  description = "Cron schedule for the in-cluster PAT rotation CronJob."
  default     = "0 3 * * *"
}

variable "netbird_pat_rotator_image" {
  type        = string
  description = "Container image (must provide curl and jq) used by the PAT bootstrap/rotation pods."
  default     = "alpine:3.20"
}

variable "self_signed" {
  type        = bool
  description = "Use a self-signed certificate instead of Let's Encrypt for the NetBird FQDN."
  default     = false
}

variable "tls_private_key" {
  type        = string
  description = "Base64 encoded TLS private key for the NetBird host. If not specified together with tls_public_key, a certificate is generated."
  default     = ""
  sensitive   = true
}

variable "tls_public_key" {
  type        = string
  description = "Base64 encoded TLS public key (certificate) for the NetBird host. If not specified together with tls_private_key, a certificate is generated."
  default     = ""
}
