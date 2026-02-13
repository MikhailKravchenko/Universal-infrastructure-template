# Application Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Универсальный репозиторий для развертывания инфраструктуры приложения в Yandex.Cloud с использованием Terraform, Kubernetes (RKE2), ArgoCD и Helm. Поддерживает несколько окружений (dev, staging, production), сервисы данных в кластере (PostgreSQL, Redis, RabbitMQ, Kafka), объектное хранилище S3, управление секретами через Yandex Lockbox и External Secrets Operator, а также стратегию бэкапов.

## Содержание

- [Краткий обзор процесса развертывания](#краткий-обзор-процесса-развертывания)
- [Описание](#описание)
- [Архитектура решения](#архитектура-решения)
- [Структура репозитория](#структура-репозитория)
- [Компоненты инфраструктуры](#компоненты-инфраструктуры)
- [Предварительные требования](#предварительные-требования)
- [Пошаговая инструкция по запуску проекта](#пошаговая-инструкция-по-запуску-проекта)
- [Переменные и конфигурация](#переменные-и-конфигурация)
- [Основные сервисы приложения](#основные-сервисы-приложения)
- [Сервисы мониторинга](#сервисы-мониторинга)
- [Мульти-окружения и сервисы данных](#мульти-окружения-и-сервисы-данных)
- [Подключение backend к БД и очередям](#подключение-backend-к-бд-и-очередям)
- [GitOps и управление деплоем](#gitops-и-управление-деплоем)
- [Сводка эндпоинтов](#сводка-эндпоинтов)
- [Makefile](#makefile)
- [Kubernetes ресурсы](#kubernetes-ресурсы-namespaceы)
- [Масштабирование кластера (добавление и удаление нод)](#масштабирование-кластера-добавление-и-удаление-нод)
- [Устранение неполадок](#устранение-неполадок)
- [Дополнительная документация](#дополнительная-документация)
- [Лицензия](#лицензия)

## Краткий обзор процесса развертывания

Процесс развертывания состоит из следующих этапов:

1. **Развертывание инфраструктуры** (Terraform) → создание ВМ, сети, Kubernetes кластера, ArgoCD
2. **Настройка секретов** → создание `docker-config-secret` для доступа к Docker Registry
3. **Публикация Helm чартов** → автоматическая публикация через GitLab CI в Nexus репозиторий
4. **Деплой через ArgoCD** → создание Application в ArgoCD для автоматического развертывания приложения и мониторинга

После завершения все сервисы доступны через Network Load Balancer по внешнему IP адресу (будет показан в выводе terraform output).

## Описание

Этот проект автоматизирует развертывание полного стека приложения в Yandex.Cloud:

- **Инфраструктура (Terraform)**: VPC, виртуальные машины с RKE2, bastion, Network Load Balancer, security groups; опционально — Object Storage (S3-совместимый бакет) и секрет в Yandex Lockbox для паролей и ключей.
- **Kubernetes**: кластер на базе RKE2 (один кластер), отдельные namespace для окружений: `dev`, `staging`, `production` с квотами и лимитами ресурсов.
- **ArgoCD**: установка при развертывании инфраструктуры; используется для GitOps-деплоя приложения, мониторинга и при необходимости — сервисов данных и конфигурации External Secrets.
- **Helm-чарты** (публикуются в Nexus через GitLab CI):
  - **app** — приложение (frontend + backend) с параметризацией по окружениям;
  - **monitoring** — Prometheus, Grafana, Loki, Promtail, Alertmanager;
  - **data-services** — umbrella-чарт Bitnami: PostgreSQL, Redis, RabbitMQ, Kafka;
  - **external-secrets-config** — ClusterSecretStore и ExternalSecret для синхронизации секретов из Lockbox в namespace кластера.
- **Секреты**: пароли и ключи не хранятся в Git; при использовании Lockbox и External Secrets Operator секреты создаются в целевых namespace автоматически. Для pull образов из приватного registry в каждом namespace создаётся секрет `docker-config-secret`.
- **Бэкапы**: скрипт `backup/pg-dump-s3.sh` и пример CronJob для ежедневного дампа PostgreSQL с выгрузкой в S3; процедуры описаны в [docs/backup.md](docs/backup.md).
- **CI/CD**: GitLab CI при изменении файлов в соответствующих директориях собирает и публикует чарты в Nexus (app, monitoring, data-services, external-secrets-config).

## Архитектура решения

Высокоуровневая схема:

1. **Yandex.Cloud (Terraform)**  
   Создаются: VPC, подсети, ВМ (RKE2 server/agents), bastion, NLB, при необходимости — S3-бакет и сервисный аккаунт, секрет в Lockbox (плейсхолдер с ключами для backend).

2. **Kubernetes (один кластер)**  
   - **Окружения**: namespace'ы `dev`, `staging`, `production` — в каждом могут быть развёрнуты приложение (app) и сервисы данных (data-services).  
   - **Мониторинг**: namespace `monitoring` — Prometheus, Grafana, Loki, Promtail, Alertmanager.  
   - **Секреты**: при использовании ESO — оператор в namespace `external-secrets`, конфигурация (SecretStore + ExternalSecret) синхронизирует секреты из Lockbox в `dev`, `staging`, `production`.  
   - **Трафик**: ingress-nginx; приложение доступно через NLB по путям `/app` и `/api`.

3. **Подключение приложения**  
   Backend получает переменные окружения из ConfigMap (хосты БД, RabbitMQ, Kafka, Redis, S3) и из Secret (пароли). Secret создаётся вручную или через External Secrets из Lockbox. Имена сервисов в одном namespace: `postgresql`, `redis-master`, `rabbitmq`, `kafka`.

## Структура репозитория

```
app-infrastructure/
├── terraform/                 # Инфраструктура в Yandex.Cloud
│   ├── main.tf                # ВМ, сеть, NLB, Ansible
│   ├── lockbox.tf             # Секрет Lockbox (опционально)
│   ├── storage.tf             # S3-бакет и ключи (опционально)
│   ├── variables.tf           # Переменные Terraform
│   ├── terraform.tfvars.example # Пример переменных (скопировать в terraform.tfvars)
│   ├── outputs.tf             # Выходные значения (IP, bucket, lockbox_secret_id)
│   ├── provider.tf            # Провайдер Yandex.Cloud
│   ├── versions.tf            # Ограничения версий
│   ├── modules/
│   │   ├── tf-yc-instance/    # Модуль виртуальной машины
│   │   └── tf-yc-network/     # Модуль сети/VPC
│   └── ansible/               # RKE2, ArgoCD, ingress-nginx
├── kubernetes/                # Плоские манифесты (справочно)
│   ├── backend/              # Deployment, Service, Ingress, ConfigMap
│   ├── frontend/
│   └── namespaces/           # dev, staging, production + ResourceQuota, LimitRange
├── app-chart/                 # Helm-чарт приложения (frontend + backend)
│   ├── Chart.yaml
│   ├── values.yaml            # Базовые значения
│   ├── values-dev.yaml        # Переопределения для dev
│   ├── values-staging.yaml
│   ├── values-production.yaml
│   └── charts/
│       ├── backend/           # Субчарт backend (ConfigMap, Deployment, Service, Ingress)
│       └── frontend/          # Субчарт frontend
├── data-services-chart/       # Umbrella: PostgreSQL, Redis, RabbitMQ, Kafka (Bitnami)
│   ├── Chart.yaml             # Зависимости от Bitnami
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   └── values-production.yaml
├── monitoring-chart/          # Prometheus, Grafana, Loki, Promtail, Alertmanager
│   ├── Chart.yaml
│   ├── values.yaml
│   └── charts/
├── external-secrets-chart/    # Конфигурация ESO: SecretStore + ExternalSecret для Lockbox
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── argocd/
│   └── applications/         # Примеры Application: app-dev, app-staging, app-production
├── backup/                   # Бэкапы PostgreSQL в S3
│   ├── pg-dump-s3.sh         # Скрипт дампа и загрузки в S3
│   └── cronjob-postgres-backup.yaml
├── docs/
│   ├── multi-env.md          # Мульти-окружения, values, ArgoCD
│   ├── secrets.md            # Lockbox, ESO, добавление ключей
│   ├── backup.md             # Стратегия бэкапов, восстановление
│   └── runbook.md            # Runbook: инциденты (ImagePullBackOff, БД, ESO, ArgoCD)
├── Makefile                  # Типовые команды (terraform, helm lint, kubectl)
├── .editorconfig             # Единый стиль кода (отступы, переносы строк)
├── .gitignore
├── .gitlab-ci.yml            # Публикация чартов в Nexus
├── CHANGELOG.md              # История изменений
├── CONTRIBUTING.md           # Правила участия в разработке
├── LICENSE                   # Лицензия MIT
├── README.md
└── SECURITY.md               # Сообщение об уязвимостях, рекомендации
```

## Компоненты инфраструктуры

| Компонент | Назначение |
|-----------|------------|
| **Terraform** | Создание и управление VPC, ВМ, NLB, опционально S3 и Lockbox. Запуск Ansible для установки RKE2, ArgoCD, ingress-nginx. |
| **RKE2** | Kubernetes-дистрибутив на ВМ; один кластер. |
| **ArgoCD** | GitOps: деплой по манифестам из Git или по Helm-чартам из Nexus. |
| **ingress-nginx** | Входная точка HTTP/HTTPS; маршрутизация по путям (/app, /api). |
| **app-chart** | Деплой frontend и backend с настраиваемыми образами, репликами, ingress и переменными для БД/очередей/S3. |
| **data-services-chart** | Деплой PostgreSQL, Redis, RabbitMQ, Kafka в выбранном namespace с разными ресурсами по окружениям. |
| **monitoring-chart** | Стек метрик и логов: Prometheus, Grafana, Loki, Promtail, Alertmanager. |
| **external-secrets-chart** | Описание ClusterSecretStore (доступ к Lockbox) и ExternalSecret (синхронизация секрета в несколько namespace). |
| **Lockbox** | Хранение паролей и ключей (БД, RabbitMQ, Redis, S3); в кластер попадают через ESO. |

## Предварительные требования

- Terraform >= 1.5.7
- Провайдер Yandex.Cloud >= 0.87.0
- Ansible >= 2.9
- kubectl (для доступа к кластеру после развертывания)
- Доступ к Yandex.Cloud с необходимыми правами
- Хранилище состояния Terraform (S3 в Object Storage от Yandex.Cloud, желательно настроить)
- GitLab CI/CD с настроенными переменными:
  - `HELM_REPO_USERNAME` — логин для Nexus Helm репозитория
  - `HELM_REPO_PASSWORD` — пароль для Nexus Helm репозитория
  - `NEXUS_HELM_REPO` — URL Helm репозитория для приложения (app)
  - `NEXUS_HELM_MONITORING_REPO` — URL Helm репозитория для monitoring
  - `NEXUS_HELM_DATA_SERVICES_REPO` (опционально) — для чарта data-services; по умолчанию используется NEXUS_HELM_REPO
  - `NEXUS_HELM_EXTERNAL_SECRETS_REPO` (опционально) — для чарта external-secrets-config

## Пошаговая инструкция по запуску проекта

### Шаг 1: Развертывание инфраструктуры

Развертывание инфраструктуры выполняется через Terraform. Процесс включает создание сети, виртуальных машин и настройку Kubernetes кластера.

#### 1.1 Настройка переменных Terraform

**Команда генерирует безопасный случайный токен длиной 64 символа в hex формате для аутентификации узлов RKE2 кластера.**

Перед настройкой переменных нужно создать RKE2 токен. Этот токен используется для аутентификации между серверами и агентами в кластере RKE2.

**Создание RKE2 токена:**

Сгенерируйте случайный токен одним из следующих способов:

```bash
# Вариант 1: Используя openssl (рекомендуется)
openssl rand -hex 32

# Вариант 2: Используя /dev/urandom
tr -dc 'a-f0-9' < /dev/urandom | head -c 64
```

Скопируйте сгенерированный токен (например: `5e234f13b4c43c929ae6533e1438241fa4509906c6420bec073591863a8ab211`).

**Важно**: Сохраните этот токен в безопасном месте, он понадобится при добавлении новых узлов в кластер.

Скопируйте `terraform/terraform.tfvars.example` в `terraform/terraform.tfvars` и заполните значения. Либо создайте файл `terraform/terraform.tfvars` вручную с необходимыми переменными:

```hcl
cloud_id = "your-cloud-id"
folder_id = "your-folder-id"
zone = "ru-central1-a"
image_id = "your-image-id"
subnet_id = "your-subnet-id"  # Если используете существующую подсеть
platform_id = "standard-v2"
rke2_token = "your-generated-rke2-token"  # Токен, сгенерированный выше
```

#### 1.2 Инициализация и применение Terraform

**Команда `terraform init`** инициализирует Terraform, загружает провайдеры и модули, настраивает backend для хранения состояния.

```bash
cd terraform
terraform init
```

**Команда `terraform plan`** показывает план изменений, которые будут применены к инфраструктуре.

```bash
terraform plan
```

**Команда `terraform apply`** применяет изменения и создает инфраструктуру в Yandex.Cloud.

```bash
terraform apply
```

После успешного выполнения должны быть:

- Созданы виртуальные машины с установленным RKE2
- Настроен Kubernetes кластер
- Установлен ArgoCD в namespace `argocd`
- Настроен ingress-nginx для маршрутизации трафика
- Создан Network Load Balancer для доступа к сервисам

#### 1.3 Получение выходных данных

**Команда `terraform output`** выводит информацию о созданных ресурсах (IP адреса, имена и т.д.). Эти данные понадобятся дальше.

```bash
terraform output
```

Сохраните следующие значения:

- `vm_external_ip` - внешний IP основной ВМ
- `nlb_external_ip` - внешний IP Load Balancer (для доступа к сервисам)
- `bastion_external_ip` - внешний IP бастион-хоста (если используется)

### Шаг 2: Настройка доступа к Kubernetes кластеру

После развертывания инфраструктуры необходимо настроить доступ к кластеру:

```bash
# Получите kubeconfig с ВМ
ssh ubuntu@<vm_external_ip> "sudo cat /etc/rancher/rke2/rke2.yaml" > ~/.kube/config

# Установите правильный IP адрес в kubeconfig
# Замените 127.0.0.1 на <vm_external_ip> в секции server:
sed -i '' "s/127.0.0.1/<vm_external_ip>/g" ~/.kube/config

# Проверьте доступ (должны увидеть ноды)
kubectl get nodes
```

### Шаг 3: Создание секретов для Docker Registry

**Важно**: Секреты нужно создать до деплоя приложения через ArgoCD, иначе поды не смогут загрузить образы из приватного Container Registry (например, GitLab).

#### 3.1 Получение учетных данных Docker Registry

Нужно иметь один из следующих вариантов:

- Deploy Token из GitLab (с правами `read_registry`)
- Personal Access Token с правами `read_registry`
- Логин и пароль пользователя GitLab

#### 3.2 Создание секрета в namespace приложения

Команда создаёт секрет типа `kubernetes.io/dockerconfigjson` для доступа к приватному Container Registry (например, GitLab). Без этого секрета поды не смогут загрузить образы приложения.

**Для одного окружения (namespace `default`):**

```bash
kubectl create secret docker-registry docker-config-secret \
  --docker-server=gitlab.praktikum-services.ru:5050 \
  --docker-username='<your_username>' \
  --docker-password='<your_token_or_password>' \
  --namespace=default
```

**Для мульти-окружений** секрет нужно создать в каждом namespace, куда деплоится приложение (`dev`, `staging`, `production`):

```bash
for ns in dev staging production; do
  kubectl create secret docker-registry docker-config-secret \
    --docker-server=gitlab.praktikum-services.ru:5050 \
    --docker-username='<your_username>' \
    --docker-password='<your_token_or_password>' \
    --namespace="$ns"
done
```

Или применить один раз в `default`, если приложение пока развёрнуто только там.

#### 3.3 Проверка секрета

```bash
kubectl get secret docker-config-secret -n default
# Должен показать секрет типа kubernetes.io/dockerconfigjson
```

### Шаг 4: Публикация Helm чартов в Nexus

Helm чарты автоматически публикуются в Nexus репозиторий через GitLab CI/CD при изменении файлов в соответствующих директориях. Перед публикацией pipeline выполняет стадию **validate**: для всех чартов запускаются `helm dependency update`, `helm lint` и `helm template` (проверка рендера манифестов).

#### 4.1 Структура чартов

В репозитории четыре типа Helm-чартов (каждый публикуется в Nexus при изменении своей директории):

| Директория | Чарт | Содержимое |
|------------|------|-------------|
| `app-chart/` | app | Frontend и backend приложения; параметры по окружениям (values-dev/staging/production). |
| `monitoring-chart/` | monitoring | Prometheus, Grafana, Loki, Promtail, Alertmanager. |
| `data-services-chart/` | data-services | PostgreSQL, Redis, RabbitMQ, Kafka (Bitnami); зависимости подтягиваются из репозитория Bitnami. |
| `external-secrets-chart/` | external-secrets-config | ClusterSecretStore и ExternalSecret для синхронизации секретов из Yandex Lockbox в namespace кластера. |

#### 4.2 Автоматическая публикация через GitLab CI

При коммите изменений в директории чартов (`app-chart/**`, `monitoring-chart/**` и т.д.) сначала выполняется стадия **validate** (job `lint-helm`): проверка всех чартов через `helm lint` и `helm template`. Затем при успешной проверке запускается job публикации (например `release-helm` для app-chart), который:

1. Обновляет зависимости чарта (`helm dependency update`)
2. Упаковывает чарт (`helm package`) — создаёт .tgz файл
3. Публикует его в Nexus репозиторий (`curl --upload-file`)

**Команды выполняются автоматически при коммите в GitLab:**

```bash
# При изменении app-chart/
cd app-chart
helm dependency update
helm package . --version "0.1.3-pipeline${CI_PIPELINE_ID}"
curl -L -u $HELM_REPO_USERNAME:$HELM_REPO_PASSWORD $NEXUS_HELM_REPO --upload-file app-*.tgz

# При изменении monitoring-chart/
cd monitoring-chart
helm dependency update
helm package . --version "0.1.0-pipeline${CI_PIPELINE_ID}"
curl -L -u $HELM_REPO_USERNAME:$HELM_REPO_PASSWORD $NEXUS_HELM_MONITORING_REPO --upload-file monitoring-*.tgz
```

#### 4.3 Триггер публикации

Для публикации чартов нужно:

1. Внести изменения в файлы Helm чарта (например, обновить `values.yaml`)
2. Закоммитьте и запушьте изменения в GitLab (git push как обычно)
3. GitLab CI автоматически определит изменения и запустит pipeline
4. Чарт будет упакован и загружен в Nexus

**Важно**: Убедитесь, что в GitLab настроены переменные `HELM_REPO_USERNAME`, `HELM_REPO_PASSWORD`, `NEXUS_HELM_REPO` и `NEXUS_HELM_MONITORING_REPO`, иначе ничего не заработает.

### Шаг 5: Деплой через ArgoCD

ArgoCD устанавливается автоматически при развертывании инфраструктуры через Ansible playbook. После установки можно деплоить приложения через веб-интерфейс ArgoCD.

#### 5.1 Получение доступа к ArgoCD

ArgoCD доступен через NodePort **32080**:

- URL: `http://<nlb_external_ip>:8080`

**Команда получает начальный пароль администратора ArgoCD из секрета Kubernetes.**

Чтобы получить пароль администратора, выполните:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

- Имя пользователя: `admin`
- Пароль: результат команды выше

#### 5.2 Настройка Helm репозитория в ArgoCD

1. Войдите в веб-интерфейс ArgoCD
2. Перейдите в **Settings** → **Repositories**
3. Нажмите **+ Connect Repo**
4. Заполните форму:
   - **Type**: `Helm`
   - **Name**: `nexus-helm-repo` (для приложения app) или `nexus-monitoring-repo` (для мониторинга)
   - **URL**: значение переменной `NEXUS_HELM_REPO` или `NEXUS_HELM_MONITORING_REPO`
   - **Username**: значение переменной `HELM_REPO_USERNAME`
   - **Password**: значение переменной `HELM_REPO_PASSWORD`
5. Нажмите **Connect** и проверьте подключение

#### 5.3 Создание Application для приложения

1. В веб-интерфейсе ArgoCD нажмите **+ New App**
2. Заполните **General**:
   - **Application Name**: `app`
   - **Project Name**: `default`
   - **Sync Policy**: `Automatic` (опционально)
3. Заполните **Source**:
   - **Repository URL**: выберите `nexus-helm-repo`
   - **Chart**: `app`
   - **Version**: последняя версия (например, `0.1.3-pipeline<ID>`, можно посмотреть в Nexus какие версии есть)
4. Заполните **Destination**:
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `default`
5. Заполните **Helm** (опционально, но можно настроить под себя):
   - Можете переопределить значения из `values.yaml`
   - Например, изменить теги образов или количество реплик
6. Нажмите **Create** и затем **Sync** (или включите автосинхронизацию)

#### 5.4 Создание Application для мониторинга

Повторите шаги 5.3 с следующими параметрами:

- **Application Name**: `monitoring`
- **Repository URL**: `nexus-monitoring-repo`
- **Chart**: `monitoring`
- **Version**: последняя версия (например, `0.1.0-pipeline<ID>`)
- **Namespace**: `monitoring`

#### 5.5 Мониторинг деплоя

После создания Application:

1. ArgoCD автоматически синхронизирует состояние
2. В интерфейсе можно отслеживать статус деплоя
3. При ошибках ArgoCD покажет детали в логах и событиях

### Переменные и конфигурация

**Terraform** (`terraform/terraform.tfvars` или переменные окружения):

| Переменная | Обязательный | Описание |
|------------|---------------|----------|
| `cloud_id` | да | Идентификатор облака Yandex.Cloud |
| `folder_id` | да | Идентификатор каталога |
| `zone` | да | Зона (ru-central1-a / b / d) |
| `image_id` | да | ID образа ВМ |
| `subnet_id` | да* | ID подсети (*если не создаётся модулем сети) |
| `platform_id` | нет | Тип платформы ВМ (standard-v1/v2/v3) |
| `rke2_token` | да | Токен для кластера RKE2 |
| `create_storage_bucket` | нет | Создать S3-бакет и ключи (по умолчанию `false`) |
| `storage_bucket_name` | при S3 | Имя бакета (если `create_storage_bucket = true`) |
| `lockbox_create_placeholder` | нет | Создать секрет в Lockbox с плейсхолдерами (по умолчанию `false`) |

После `terraform apply` при включённом S3/Lockbox полезны выходы: `storage_bucket_name`, `storage_s3_access_key`, `storage_s3_secret_key`, `lockbox_secret_id`.

**GitLab CI/CD** (Settings → CI/CD → Variables):

| Переменная | Назначение |
|------------|------------|
| `HELM_REPO_USERNAME` | Логин для Nexus (Helm-репозитории) |
| `HELM_REPO_PASSWORD` | Пароль |
| `NEXUS_HELM_REPO` | URL репозитория для чарта app |
| `NEXUS_HELM_MONITORING_REPO` | URL репозитория для monitoring |
| `NEXUS_HELM_DATA_SERVICES_REPO` | (опционально) для data-services; по умолчанию используется NEXUS_HELM_REPO |
| `NEXUS_HELM_EXTERNAL_SECRETS_REPO` | (опционально) для external-secrets-config |

### Основные сервисы приложения

Для production в [app-chart/values-production.yaml](app-chart/values-production.yaml) включены **HPA** (HorizontalPodAutoscaler) и **PDB** (PodDisruptionBudget) для backend и frontend: масштабирование по CPU и защита от одновременного простоя нескольких реплик при обновлениях узлов. Настройка в values: `backend.hpa`, `backend.pdb`, `frontend.hpa`, `frontend.pdb`.

| Сервис             | Endpoint                                       | Описание                            |
| ------------------ | ---------------------------------------------- | ----------------------------------- |
| **Frontend**       | `http://<nlb_external_ip>/app`                 | Веб-интерфейс приложения            |
| **Backend API**    | `http://<nlb_external_ip>/api`                 | REST API бэкенда приложения         |
| **Backend Health** | `http://<nlb_external_ip>/api/actuator/health` | Health check эндпоинт бэкенда       |

**Примеры доступа (подставьте свой IP вместо <nlb_external_ip>):**

- Главная страница: `http://<nlb_external_ip>/app`
- API endpoint: `http://<nlb_external_ip>/api/products`
- Health check: `http://<nlb_external_ip>/api/actuator/health`

### Сервисы мониторинга

| Сервис         | Endpoint                        | Порт (NodePort) | Описание                                                  |
| -------------- | ------------------------------- | --------------- | --------------------------------------------------------- |
| **Prometheus**     | `http://<nlb_external_ip>:9090` | 32090           | Сбор и хранение метрик                                    |
| **Grafana**        | `http://<nlb_external_ip>:3000` | 32300           | Визуализация метрик и дашборды (по умолчанию admin/admin) |
| **Loki**           | `http://<nlb_external_ip>:3100` | 32310           | Сбор и хранение логов                                     |
| **Alertmanager**   | `http://<nlb_external_ip>:9093` | 32093           | Приём алертов от Prometheus, маршрутизация (Slack, email); настройка в values или docs/runbook.md |

**Примечание**: Сервисы мониторинга доступны напрямую через NodePort, так как они не проходят через ingress-nginx (можно было бы через ingress, но так проще было сделать).

### Мульти-окружения и сервисы данных

**Окружения**  
В одном кластере используются отдельные namespace: `dev`, `staging`, `production`. Для каждого заданы ResourceQuota и LimitRange (ограничения по CPU/памяти и подам). Манифесты: [kubernetes/namespaces/](kubernetes/namespaces/). Примеры ArgoCD Application для приложения по окружениям: [argocd/applications/](argocd/applications/) (app-dev, app-staging, app-production). Подробный порядок деплоя и использование values по окружениям — в [docs/multi-env.md](docs/multi-env.md).

**Сервисы данных (data-services-chart)**  
Чарт [data-services-chart/](data-services-chart/) разворачивает в выбранном namespace:

- **PostgreSQL** (Bitnami) — СУБД; сервис `postgresql`, порт 5432, база по умолчанию `app_store`.
- **Redis** (Bitnami) — кэш/сессии; сервис `redis-master`, порт 6379.
- **RabbitMQ** (Bitnami) — очереди; сервис `rabbitmq`, порт 5672.
- **Kafka** (Bitnami) — стриминг; bootstrap-адрес `kafka:9092`.

Ресурсы и пароли настраиваются в `values.yaml` и в файлах `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`. Пароли для БД и очередей не хранятся в Git — задаются через values при установке или через секреты (в т.ч. из Lockbox).

**S3 (Object Storage)**  
При необходимости бакет и статические ключи доступа создаются в Terraform: переменные `create_storage_bucket = true` и `storage_bucket_name`. Ключи выводятся в `terraform output`; их рекомендуется сохранить в Lockbox (ключи `S3_ACCESS_KEY`, `S3_SECRET_KEY`) и передавать в backend через секреты. Подробнее: [docs/backup.md](docs/backup.md).

**Секреты и бэкапы**  
Управление секретами (Lockbox, ESO, добавление ключей): [docs/secrets.md](docs/secrets.md). Стратегия бэкапов и восстановление: [docs/backup.md](docs/backup.md).

### Подключение backend к БД и очередям

Чтобы backend использовал PostgreSQL, RabbitMQ, Kafka и Redis, в чарте приложения (app) нужно задать переменные окружения. Они формируются из:

1. **ConfigMap** (несекретные данные): URL БД, хосты RabbitMQ/Kafka/Redis, параметры S3 (endpoint, bucket, region). Чарт backend создаёт ConfigMap, если в values указано `backend.env.configMapName` (например `backend-config`).
2. **Secret** (пароли и ключи): логины/пароли БД, RabbitMQ, Redis, ключи S3. Secret создаётся вручную или через External Secrets из Lockbox; в values указывается `backend.env.secretName` (например `backend-secrets`).

В [app-chart/values.yaml](app-chart/values.yaml) блок `backend.env` по умолчанию закомментирован. Для работы с сервисами данных его нужно раскомментировать и задать (в values или в параметрах ArgoCD Application):

```yaml
backend:
  env:
    secretName: backend-secrets
    configMapName: backend-config
    dataServices:
      postgresqlHost: postgresql
      postgresqlPort: "5432"
      postgresqlDatabase: app_store
      rabbitmqHost: rabbitmq
      rabbitmqPort: "5672"
      kafkaBootstrapServers: kafka:9092
      redisHost: redis-master
      redisPort: "6379"
      s3Endpoint: https://storage.yandexcloud.net
      s3Bucket: your-bucket-name
      s3Region: ru-central1
```

Имена хостов приведены для случая, когда приложение и data-services развёрнуты в одном namespace. Подробнее: [docs/multi-env.md](docs/multi-env.md) и [docs/secrets.md](docs/secrets.md).

### GitOps и управление деплоем

| Сервис        | Endpoint                        | Порт (NodePort) | Описание                                     |
| ------------- | ------------------------------- | --------------- | -------------------------------------------- |
| **ArgoCD UI** | `http://<nlb_external_ip>:8080` | 32080           | Веб-интерфейс ArgoCD для управления деплоями |

### Сводка эндпоинтов

| Категория   | Сервис         | Endpoint / примечание |
| ----------- | --------------- | --------------------- |
| Приложение  | Frontend        | `http://<nlb_external_ip>/app` |
| Приложение  | Backend API     | `http://<nlb_external_ip>/api` |
| Приложение  | Backend Health  | `http://<nlb_external_ip>/api/actuator/health` |
| Мониторинг  | Prometheus      | `http://<nlb_external_ip>:9090` (NodePort 32090) |
| Мониторинг  | Grafana         | `http://<nlb_external_ip>:3000` (NodePort 32300) |
| Мониторинг  | Loki            | `http://<nlb_external_ip>:3100` (NodePort 32310) |
| Мониторинг  | Alertmanager    | `http://<nlb_external_ip>:9093` (NodePort 32093) |
| GitOps      | ArgoCD UI       | `http://<nlb_external_ip>:8080` (NodePort 32080) |

### Makefile

В корне репозитория есть [Makefile](Makefile) с типовыми командами (секреты и переменные задаются отдельно через `terraform.tfvars` или переменные окружения).

| Цель | Описание |
|------|----------|
| `make help` | Список всех целей |
| `make terraform-init` | Инициализация Terraform в `terraform/` |
| `make terraform-plan` | План изменений инфраструктуры |
| `make terraform-apply` | Применение изменений Terraform |
| `make helm-lint` | Проверка всех Helm-чартов (`helm lint`) |
| `make helm-package-app` | Локальная упаковка чарта app |
| `make helm-package-monitoring` | Локальная упаковка чарта monitoring |
| `make helm-package-data-services` | Локальная упаковка чарта data-services |
| `make helm-package-external-secrets` | Локальная упаковка чарта external-secrets-config |
| `make kubectl-apply-namespaces` | Применить манифесты namespace (dev, staging, production) |

Примеры:

```bash
make terraform-init
make helm-lint
make kubectl-apply-namespaces
```

### Kubernetes ресурсы (namespace'ы)

| Namespace            | Приложения                               | Описание                         |
| -------------------- | ---------------------------------------- | -------------------------------- |
| `default`            | app (если деплой в default)               | Основное приложение              |
| `dev`                | app, data-services (при использовании)   | Окружение разработки             |
| `staging`            | app, data-services                       | Предпрод                          |
| `production`         | app, data-services                       | Прод                              |
| `monitoring`         | Prometheus, Grafana, Loki, Promtail, Alertmanager | Стек мониторинга                 |
| `argocd`             | ArgoCD компоненты                        | GitOps контроллер                |
| `external-secrets`   | External Secrets Operator, конфиг        | Синхронизация секретов из Lockbox |
| `backup`             | CronJob дампа PostgreSQL (опционально)   | Бэкапы в S3                      |
| `kube-system`        | RKE2, ingress-nginx                      | Системные сервисы                |
| `local-path-storage` | local-path-provisioner                   | Динамическое хранилище           |

### Масштабирование кластера (добавление и удаление нод)

Кластер RKE2 по умолчанию развёрнут на **трёх нодах** (три ВМ в модуле `vm_instance` в [terraform/main.tf](terraform/main.tf)): первая нода — RKE2 server (primary), остальные — RKE2 agent. При нехватке ресурсов кластер можно расширить, добавив машины; при необходимости — безопасно убрать ноду. Target group Network Load Balancer и Ansible-инвентарь привязаны к списку нод и обновляются автоматически при изменении `instance_count`.

#### Добавление ноды

При увеличении `instance_count` Terraform создаёт только новые ВМ (существующие не пересоздаются), поэтому текущие ноды не затрагиваются.

1. **Увеличить число нод в Terraform**  
   В [terraform/main.tf](terraform/main.tf) в блоке `module "vm_instance"` изменить параметр `instance_count` (например с `3` на `4`):

   ```hcl
   module "vm_instance" {
     source         = "./modules/tf-yc-instance"
     # ...
     instance_count = 4   # было 3
     # ...
   }
   ```

2. **Применить изменения**  
   Выполнить план и применение (из каталога с Terraform или через Makefile):

   ```bash
   cd terraform
   terraform plan   # убедиться, что создаётся только новая ВМ и обновляется inventory
   terraform apply
   ```

   После `apply` появится новая ВМ, обновится файл [terraform/ansible/inventory.ini](terraform/ansible/inventory.ini) (в группе `rke2` будет четыре хоста), а внутренний IP новой ноды автоматически попадёт в target group NLB.

3. **Установить RKE2 на новой ноде**  
   Плейбук [terraform/ansible/rke2-install.yml](terraform/ansible/rke2-install.yml) идемпотентный: на уже работающих нодах установка пропускается (`creates: /usr/local/bin/rke2` / `rke2-agent`), на новой — ставится RKE2 agent и выполняется join к кластеру. Запустить плейбук по всем хостам (токен взять из `terraform.tfvars` или переменных окружения):

   ```bash
   cd terraform
   ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
     -i ansible/inventory.ini \
     ansible/rke2-install.yml \
     --extra-vars "rke2_token=<ваш_rke2_token>"
   ```

   При необходимости можно ограничить выполнение только новой нодой, например: `--limit node-4`.

4. **Проверить**  
   С bastion или с машины, где настроен доступ к кластеру:

   ```bash
   kubectl get nodes
   ```

   Новая нода должна появиться в списке и перейти в состояние `Ready`.

#### Удаление ноды

При уменьшении `instance_count` Terraform **удаляет одну ВМ — с наибольшим индексом** (например при переходе с 4 на 3 будет удалена четвёртая нода). Чтобы не потерять поды и не нарушить работу приложений, ноду нужно сначала корректно вывести из кластера (drain), затем уменьшить `instance_count` и применить Terraform.

1. **Определить, какую ноду убирать**  
   При уменьшении `instance_count` Terraform всегда удаляет последнюю по индексу ВМ (добавленную последней). Убедитесь, что это та нода, которую вы хотите вывести из кластера. Список нод:

   ```bash
   kubectl get nodes
   ```

2. **Запретить планирование подов и эвакуировать ноду**  
   Выполнить с bastion или с машины, где настроен `kubeconfig`:

   ```bash
   # Заменить <имя-ноды> на имя ноды из kubectl get nodes (например node-4)
   kubectl cordon <имя-ноды>
   kubectl drain <имя-ноды> --ignore-daemonsets --delete-emptydir-data
   ```

   После `drain` поды с этой ноды переедут на другие ноды. При необходимости ноду можно удалить из API кластера: `kubectl delete node <имя-ноды>` (опционально — после уничтожения ВМ она исчезнет из списка сама).

3. **Уменьшить число нод в Terraform**  
   В [terraform/main.tf](terraform/main.tf) в блоке `module "vm_instance"` вернуть или задать нужное значение `instance_count` (например с `4` на `3`).

4. **Применить изменения**  
   ```bash
   cd terraform
   terraform plan   # убедиться, что destroy только одной ВМ
   terraform apply
   ```

   После `apply` одна ВМ будет удалена, инвентарь Ansible и target group NLB обновятся автоматически.

**Важно:** не уменьшайте число нод без предварительного `drain` — иначе поды на удаляемой ноде перейдут в состояние Terminating/Unknown и возможны сбои. Не удаляйте первую ноду (primary RKE2 server), если не настроено HA для control plane — при текущей схеме Terraform при уменьшении count убирает последнюю ноду по индексу, то есть не primary.

### Устранение неполадок

Подробные пошаговые сценарии и команды — в [docs/runbook.md](docs/runbook.md). Кратко:

- **Поды приложения в состоянии ImagePullBackOff**  
  Убедитесь, что в namespace развёрнут секрет `docker-config-secret` типа `kubernetes.io/dockerconfigjson` и что логин/пароль (или токен) Registry верные. Для мульти-окружений секрет должен быть в каждом namespace (`dev`, `staging`, `production`).

- **Backend не подключается к БД или очередям**  
  Проверьте, что заданы `backend.env.secretName` и `backend.env.configMapName`, развёрнут Secret с паролями и ConfigMap с хостами. Имена сервисов должны соответствовать развёрнутому data-services в том же namespace (например `postgresql`, `redis-master`, `rabbitmq`, `kafka`).

- **External Secrets не создаёт Secret в namespace**  
  Проверьте: установлен ли ESO в кластере; создан ли Secret с авторизованным ключом Yandex в namespace `external-secrets`; в values чарта external-secrets-config указаны `lockboxSecretId` и `targetNamespaces`. Статус: `kubectl get externalsecret -A`, логи оператора ESO.

- **ArgoCD показывает OutOfSync или ошибку**  
  Проверьте версию чарта в Nexus и что в Application указана существующая версия. Убедитесь, что репозиторий Helm в ArgoCD подключён (Settings → Repositories) и что credentials верные.

- **Terraform: ошибка при создании бакета или Lockbox**  
  Проверьте права сервисного аккаунта/пользователя в каталоге (роли `storage.admin`, `lockbox.admin` или аналог). Для бакета имя должно быть глобально уникальным.

### Дополнительная документация

| Документ | Содержание |
|----------|-------------|
| [docs/multi-env.md](docs/multi-env.md) | Мульти-окружения: namespace, values по env, ArgoCD, порядок деплоя. |
| [docs/secrets.md](docs/secrets.md) | Управление секретами: Lockbox, ESO, добавление ключей, подключение backend. |
| [docs/backup.md](docs/backup.md) | Стратегия бэкапов, CronJob PostgreSQL → S3, восстановление из дампа. |
| [docs/runbook.md](docs/runbook.md) | Runbook: типовые инциденты (ImagePullBackOff, БД, ESO, ArgoCD), команды и проверки. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Как предложить изменения: ветки, MR, проверки перед коммитом. |
| [SECURITY.md](SECURITY.md) | Сообщение об уязвимостях и рекомендации по безопасному использованию. |
| [CHANGELOG.md](CHANGELOG.md) | История изменений проекта. |

Дополнительно: примеры манифестов в [kubernetes/](kubernetes/), примеры ArgoCD Application в [argocd/applications/](argocd/applications/).

### Лицензия

Проект распространяется под лицензией **MIT**: репозиторий можно свободно использовать, копировать, изменять и распространять (в том числе в коммерческих целях). В копиях и производных работах необходимо сохранять текст лицензии и указание авторства.

Полный текст лицензии: [LICENSE](LICENSE).

### Лицензия

Репозиторий распространяется под лицензией **MIT**: его можно свободно использовать, копировать, изменять и распространять (в том числе в коммерческих целях) при сохранении текста лицензии и указании авторства. Полный текст — в файле [LICENSE](LICENSE).
