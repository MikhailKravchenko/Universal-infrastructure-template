data "yandex_vpc_subnet" "default" {
  subnet_id = var.subnet_id
}

resource "yandex_compute_instance" "vm-1" {
  name        = var.vm_name
  platform_id = var.platform_id
  zone        = var.zone

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  metadata = {
    user-data = var.user_data
  }
}
