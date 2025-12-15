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
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  ingress {
    description       = "Allow all UDP traffic between nodes"
    protocol          = "UDP"
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

module "bastion" {
  source             = "./modules/tf-yc-instance"
  image_id           = var.image_id
  subnet_id          = module.network.yandex_vpc_subnets[var.zone]
  zone               = var.zone
  platform_id        = var.platform_id
  instance_count     = 1
  vm_name            = "bastion"
  cores              = 2
  memory             = 4
  user_data          = file("${path.module}/scripts/add-ssh-bastion.yaml")
  security_group_ids = [yandex_vpc_security_group.k8s_nodes.id]

  depends_on = [
    module.network
  ]
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible/inventory.ini.tmpl", {
    ips      = module.vm_instance.vm_external_ip
    ssh_user = var.ssh_user
  })

  filename = "${path.module}/ansible/inventory.ini"
}

resource "null_resource" "provision_rke2" {
  depends_on = [
    module.vm_instance,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${path.module}/ansible/inventory.ini ${path.module}/ansible/rke2-install.yml --extra-vars \"rke2_token=${var.rke2_token}\""
  }
}

resource "null_resource" "copy_kubeconfig_to_bastion" {
  depends_on = [
    null_resource.provision_rke2,
    module.bastion
  ]

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no ${path.module}/ansible/kubeconfig/rke2.yaml ubuntu@${module.bastion.vm_external_ip[0]}:/home/ubuntu/rke2.yaml"
  }
}
