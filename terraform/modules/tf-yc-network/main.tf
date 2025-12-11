

data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "default" {
  for_each = toset(var.network_zones)

  name = "default-${each.key}"
}
