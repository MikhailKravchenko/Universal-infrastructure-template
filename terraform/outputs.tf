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

# Object Storage (если create_storage_bucket = true)
output "storage_bucket_name" {
  description = "Name of created S3 bucket"
  value       = var.create_storage_bucket && var.storage_bucket_name != "" ? yandex_storage_bucket.app_bucket[0].bucket : null
}

output "storage_s3_access_key" {
  description = "S3 access key — сохраните в Lockbox (S3_ACCESS_KEY)"
  value       = var.create_storage_bucket && var.storage_bucket_name != "" ? yandex_iam_service_account_static_access_key.storage_sa_key[0].access_key : null
  sensitive   = true
}

output "storage_s3_secret_key" {
  description = "S3 secret key — сохраните в Lockbox (S3_SECRET_KEY)"
  value       = var.create_storage_bucket && var.storage_bucket_name != "" ? yandex_iam_service_account_static_access_key.storage_sa_key[0].secret_key : null
  sensitive   = true
}

# Lockbox (если lockbox_create_placeholder = true)
output "lockbox_secret_id" {
  description = "ID секрета Lockbox для настройки External Secrets Operator"
  value       = var.lockbox_create_placeholder ? yandex_lockbox_secret.backend_secrets[0].id : null
}
