output "yandex_vpc_subnets" {
  description = "Yandex.Cloud Subnets map"
  value       = data.yandex_vpc_subnet.default
}

output "vm_external_ip" {
  description = "External IP VM "
  value       = try(yandex_compute_instance.vm-1.network_interface.0.nat_ip_address, null)
}

output "vm_internal_ip" {
  description = "Internal IP VM"
  value       = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "vm_name" {
  description = "Name VM"
  value       = yandex_compute_instance.vm-1.name
}

output "vm_zone" {
  description = "Zone VM"
  value       = yandex_compute_instance.vm-1.zone
}

output "vm_status" {
  description = "Status VM"
  value       = yandex_compute_instance.vm-1.status
}


