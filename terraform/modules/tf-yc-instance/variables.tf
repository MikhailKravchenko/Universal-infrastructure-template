variable "vm_name" {
  description = "Name virtual machine"
  type        = string
  default     = "momo-store"
}

variable "cores" {
  description = "CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in GB"
  type        = number
  default     = 2
}

variable "image_id" {
  description = "ID boot image"
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "ID subnet"
  type        = string
  sensitive   = false
  nullable    = false
}

variable "zone" {
  default     = "ru-central1-a"
  type        = string
  description = "Default zone for infrastructure"
  validation {
    condition     = contains(toset(["ru-central1-a", "ru-central1-b", "ru-central1-d"]), var.zone)
    error_message = "Select availability zone from the list: ru-central1-a, ru-central1-b, ru-central1-d."
  }
  nullable = false
}

variable "platform_id" {
  default     = "standard-v1"
  type        = string
  description = "Instance physical processor"
  validation {
    condition     = contains(toset(["standard-v1", "standard-v2", "standard-v3"]), var.platform_id)
    error_message = "SOne of list: standard-v1, standard-v2, standard-v3."
  }
  sensitive = true
  nullable  = false
}

variable "disk_size" {
  description = "Boot disk size GB"
  type        = number
  default     = 20
}

variable "preemptible" {
  description = "Use preemptible instance"
  type        = bool
  default     = false
}
variable "user_data" {
  description = "User data"
  type        = string
}
