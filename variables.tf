variable "head_host" {
  type        = string
  description = "FQDN/IP address of node/LB, where head services are running"
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
