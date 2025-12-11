# Yandex.Cloud Virtual Machine Module

## Описание

Модуль для создания виртуальной машины (ВМ) в Yandex.Cloud с указанным образом, зоной и конфигурацией платформы.

## Параметры

| Имя переменной | Тип    | Описание                                                | Значение по умолчанию |
| -------------- | ------ | ------------------------------------------------------- | --------------------- |
| `zone`         | string | Зона размещения ВМ (`ru-central1-a`, и т.д.)            | `"ru-central1-a"`     |
| `platform_id`  | string | Платформа (`standard-v1`, `standard-v2`, `standard-v3`) | `"standard-v1"`       |
| `image_id`     | string | ID образа диска, с которого создается ВМ                | -                     |
| `subnet_id`    | string | ID подсети, к которой подключается ВМ                   | -                     |

## Выводы

| Имя              | Описание                       |
| ---------------- | ------------------------------ |
| `vm_name`        | Имя созданной ВМ               |
| `vm_zone`        | Зона, в которой расположена ВМ |
| `vm_status`      | Статус ВМ                      |
| `vm_external_ip` | Внешний IP-адрес ВМ            |
| `vm_internal_ip` | Внутренний IP-адрес ВМ         |

## Пример использования

```hcl
module "vm_instance" {
  source      = "./modules/tf-yc-instance"
  image_id    = var.image_id
  subnet_id   = module.network.yandex_vpc_subnets[var.zone]
  zone        = var.zone
  platform_id = var.platform_id

  depends_on = [module.network]
}
```
