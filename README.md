# infrastructure

# Terraform Yandex.Cloud Infrastructure

## Описание

Этот проект разворачивает базовую инфраструктуру в Yandex.Cloud с помощью Terraform. Он включает:

- Сетевой модуль (`tf-yc-network`)
- Виртуальную машину (`tf-yc-instance`) с внешним и внутренним IP

## Зависимости

- Terraform >= 1.5.7
- Провайдер Yandex.Cloud >= 0.87.0
- Хранилище состояния (S3 в Object Storage от Yandex.Cloud)

## Переменные

| Имя переменной | Тип      | Описание                                                             | По умолчанию      | Обязательная |
| -------------- | -------- | -------------------------------------------------------------------- | ----------------- | ------------ |
| `platform_id`  | `string` | Платформа процессора (`standard-v1`, `standard-v2`, `standard-v3`)   | `"standard-v1"`   | true         |
| `zone`         | `string` | Зона доступности (`ru-central1-a`, `ru-central1-b`, `ru-central1-d`) | `"ru-central1-a"` | true         |
| `cloud_id`     | `string` | Cloud ID, используется провайдером                                   | -                 | true         |
| `folder_id`    | `string` | Folder ID, используется провайдером                                  | -                 | true         |
| `image_id`     | `string` | ID образа диска для создания ВМ                                      | -                 | true         |
| `subnet_id`    | `string` | ID подсети для ВМ                                                    | -                 | true         |

| Имя                 | Описание                                     |
| ------------------- | -------------------------------------------- |
| `vm_external_ip`    | Внешний IP-адрес виртуальной машины          |
| `vm_internal_ip`    | Внутренний IP-адрес виртуальной машины       |
| `vm_name`           | Имя созданной виртуальной машины             |
| `vm_zone`           | Зона, в которой размещена виртуальная машина |
| `vm_status`         | Текущий статус виртуальной машины            |
| `vpc_network_id`    | ID созданной сети                            |
| `available_subnets` | Список доступных подсетей по зонам           |

## Использование

Создайте файл terraform.tfvars с необходимыми значениями:

```
cloud_id = "..."
folder_id = "..."
zone = "ru-central1-a"
image_id = "..."
subnet_id = "..."
platform_id = "standard-v2"
```

```bash
terraform init
terraform plan
terraform apply
```
