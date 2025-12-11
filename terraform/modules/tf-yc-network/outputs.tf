output "vpc_network_id" {
  description = "ID default VPC"
  value       = data.yandex_vpc_network.default.id
}

output "available_subnets" {
  value = {
    for zone, subnet in data.yandex_vpc_subnet.default :
    zone => {
      id   = subnet.id
      zone = subnet.zone
      name = subnet.name
    }
  }
}
output "yandex_vpc_subnets" {
  description = "Yandex.Cloud Subnets"
  value = {
    for zone, subnet in data.yandex_vpc_subnet.default : zone => subnet.id
  }
}
