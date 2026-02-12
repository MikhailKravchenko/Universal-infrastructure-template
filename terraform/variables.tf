variable "cloud_id" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "folder_id" {
  type      = string
  sensitive = true
  nullable  = false
}
variable "zone" {
  default     = "ru-central1-a"
  type        = string
  description = "Default zone"
  validation {
    condition     = contains(toset(["ru-central1-a", "ru-central1-b", "ru-central1-d"]), var.zone)
    error_message = "Select availability zone from the list: ru-central1-a, ru-central1-b, ru-central1-d."
  }
  nullable = false
}



variable "image_id" {
  type        = string
  description = "Disk image"
  sensitive   = true
  nullable    = false
}
variable "platform_id" {
  type        = string
  default     = "standard-v1"
  description = "Platform ID"
  validation {
    condition     = contains(toset(["standard-v1", "standard-v2", "standard-v3"]), var.platform_id)
    error_message = "Select physical processor from the list: standard-v1, standard-v2, standard-v3."
  }
  sensitive = true
  nullable  = false
}

variable "ssh_user" {
  type        = string
  description = "SSH user for Ansible"
  default     = "ubuntu"
}

variable "rke2_token" {
  type        = string
  description = "Shared token for RKE2 cluster (server/agents)"
  sensitive   = true
  nullable    = false
}

# Object Storage (S3-совместимое)
variable "storage_bucket_name" {
  type        = string
  description = "Name of Yandex Object Storage bucket (for app files and/or backups)"
  default     = ""
}

variable "create_storage_bucket" {
  type        = bool
  description = "Create S3 bucket and service account with static key"
  default     = false
}

# Lockbox (секреты для ESO)
variable "lockbox_create_placeholder" {
  type        = bool
  description = "Create a placeholder Lockbox secret for backend (fill payload manually or via CLI)"
  default     = false
}

