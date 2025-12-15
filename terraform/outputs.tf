output "vm_external_ip" {
  value = module.vm_instance.vm_external_ip
}


output "vm_internal_ip" {
  value = module.vm_instance.vm_internal_ip
}


output "vm_name" {
  value = module.vm_instance.vm_name
}


output "vm_zone" {
  value = module.vm_instance.vm_zone
}


output "vm_status" {
  value = module.vm_instance.vm_status
}

output "bastion_external_ip" {
  description = "External IP of bastion host for kubectl access"
  value       = module.bastion.vm_external_ip[0]
}

output "bastion_internal_ip" {
  description = "Internal IP of bastion host"
  value       = module.bastion.vm_internal_ip[0]
}


output "vpc_network_id" {
  value = module.network.vpc_network_id
}

output "available_subnets" {
  value = module.network.available_subnets
}

output "nlb_external_ip" {
  description = "External IP of k8s-http-nlb"
  value = flatten([
    for l in yandex_lb_network_load_balancer.external_http.listener : [
      for a in l.external_address_spec : a.address
    ]
  ])[0]
}
