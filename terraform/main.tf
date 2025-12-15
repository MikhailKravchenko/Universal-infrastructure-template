module "network" {
  source = "./modules/tf-yc-network"
}

module "vm_instance" {
  source         = "./modules/tf-yc-instance"
  image_id       = var.image_id
  subnet_id      = module.network.yandex_vpc_subnets[var.zone]
  zone           = var.zone
  platform_id    = var.platform_id
  instance_count = 3
  user_data      = file("${path.module}/scripts/add-ssh-web-app.yaml")

  depends_on = [
    module.network
  ]
}
