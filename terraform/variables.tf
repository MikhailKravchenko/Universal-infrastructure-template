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

variable "subnet_id" {
  type        = string
  description = "Subnet ID"
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

