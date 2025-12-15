module "network" {
  source = "./modules/tf-yc-network"
}

resource "yandex_vpc_security_group" "k8s_nodes" {
  name        = "k8s-nodes-sg"
  description = "Security group for RKE2 Kubernetes nodes"
  network_id  = module.network.vpc_network_id

  ingress {
    description       = "Allow all TCP traffic between nodes"
    protocol          = "TCP"
    port              = 0
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  ingress {
    description       = "Allow all UDP traffic between nodes"
    protocol          = "UDP"
    port              = 0
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  ingress {
    description    = "Allow SSH from anywhere"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound traffic"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

module "vm_instance" {
  source             = "./modules/tf-yc-instance"
  image_id           = var.image_id
  subnet_id          = module.network.yandex_vpc_subnets[var.zone]
  zone               = var.zone
  platform_id        = var.platform_id
  instance_count     = 3
  user_data          = file("${path.module}/scripts/add-ssh-web-app.yaml")
  security_group_ids = [yandex_vpc_security_group.k8s_nodes.id]

  depends_on = [
    module.network
  ]
}
