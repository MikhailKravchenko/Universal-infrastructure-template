output "yandex_vpc_subnets" {
  description = "Yandex.Cloud Subnets map"
  value       = data.yandex_vpc_subnet.default
}

output "vm_external_ip" {
  description = "External IP VM "
  value = [
    for inst in yandex_compute_instance.vm :
    try(inst.network_interface.0.nat_ip_address, null)
  ]
}

output "vm_internal_ip" {
  description = "Internal IP VM"
  value = [
    for inst in yandex_compute_instance.vm :
    inst.network_interface.0.ip_address
  ]
}

output "vm_name" {
  description = "Name VM"
  value = [
    for inst in yandex_compute_instance.vm :
    inst.name
  ]
}

output "vm_zone" {
  description = "Zone VM"
  value = [
    for inst in yandex_compute_instance.vm :
    inst.zone
  ]
}

output "vm_status" {
  description = "Status VM"
  value = [
    for inst in yandex_compute_instance.vm :
    inst.status
  ]
}


