variable "network_zones" {
  description = "Zone's list"
  type        = set(string)
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
}
