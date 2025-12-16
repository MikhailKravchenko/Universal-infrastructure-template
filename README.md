# Momo Store Infrastructure

Проект для развертывания полной инфраструктуры приложения Momo Store в Yandex.Cloud с использованием Terraform, Kubernetes (RKE2), ArgoCD и Helm.

## Краткий обзор процесса развертывания

Процесс развертывания состоит из следующих этапов:

1. **Развертывание инфраструктуры** (Terraform) → создание ВМ, сети, Kubernetes кластера, ArgoCD
2. **Настройка секретов** → создание `docker-config-secret` для доступа к Docker Registry
3. **Публикация Helm чартов** → автоматическая публикация через GitLab CI в Nexus репозиторий
4. **Деплой через ArgoCD** → создание Application в ArgoCD для автоматического развертывания приложения и мониторинга

После завершения все сервисы доступны через Network Load Balancer по внешнему IP адресу (будет показан в выводе terraform output).

## Описание

Этот проект автоматизирует развертывание полного стека приложения Momo Store, включая:

- Инфраструктуру в Yandex.Cloud (сеть, ВМ, Load Balancer)
- Kubernetes кластер на базе RKE2
- ArgoCD для GitOps-деплоя
- Helm чарты для приложения и мониторинга
- Интеграцию с GitLab CI/CD и Nexus репозиторием

## Предварительные требования

- Terraform >= 1.5.7
- Провайдер Yandex.Cloud >= 0.87.0
- Ansible >= 2.9
- kubectl (для доступа к кластеру после развертывания)
- Доступ к Yandex.Cloud с необходимыми правами
- Хранилище состояния Terraform (S3 в Object Storage от Yandex.Cloud, желательно настроить)
- GitLab CI/CD с настроенными переменными:
  - `HELM_REPO_USERNAME` - логин для Nexus Helm репозитория
  - `HELM_REPO_PASSWORD` - пароль для Nexus Helm репозитория
  - `NEXUS_HELM_REPO` - URL Helm репозитория для momo-store
  - `NEXUS_HELM_MONITORING_REPO` - URL Helm репозитория для monitoring

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

Создайте файл `terraform/terraform.tfvars` с необходимыми значениями :

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

**Важно**: Секреты нужно создать до деплоя приложения через ArgoCD, иначе поды не смогут загрузить образы из приватного GitLab Registry (

#### 3.1 Получение учетных данных Docker Registry

Нужно иметь один из следующих вариантов:

- Deploy Token из GitLab (с правами `read_registry`)
- Personal Access Token с правами `read_registry`
- Логин и пароль пользователя GitLab

#### 3.2 Создание секрета в namespace приложения

** Создает секрет типа `kubernetes.io/dockerconfigjson` в namespace `default` для доступа к GitLab Container Registry.**

Если у вас есть логин и токен, выполните:

```bash
kubectl create secret docker-registry docker-config-secret \
  --docker-server=gitlab.praktikum-services.ru:5050 \
  --docker-username='<your_username>' \
  --docker-password='<your_token_or_password>' \
  --namespace=default
```

#### 3.3 Проверка секрета

```bash
kubectl get secret docker-config-secret -n default
# Должен показать секрет типа kubernetes.io/dockerconfigjson
```

### Шаг 4: Публикация Helm чартов в Nexus

Helm чарты автоматически публикуются в Nexus репозиторий через GitLab CI/CD при изменении файлов в соответствующих директориях.

#### 4.1 Структура чартов

Проект содержит два основных Helm чарта:

- `momo-store-chart/` - чарт для приложения (frontend + backend)
- `monitoring-chart/` - чарт для стека мониторинга (Prometheus, Grafana, Loki, Promtail)

#### 4.2 Автоматическая публикация через GitLab CI

При коммите изменений в директорию `momo-store-chart/**/*` автоматически запускается job `release-helm`, который:

1. Обновляет зависимости чарта (`helm dependency update`)
2. Упаковывает чарт (`helm package`) - создает .tgz файл
3. Публикует его в Nexus репозиторий (`curl --upload-file`)

**Команды выполняются автоматически при коммите в GitLab:**

```bash
# При изменении momo-store-chart/
cd momo-store-chart
helm dependency update
helm package . --version "0.1.3-pipeline${CI_PIPELINE_ID}"
curl -L -u $HELM_REPO_USERNAME:$HELM_REPO_PASSWORD $NEXUS_HELM_REPO --upload-file momo-store-*.tgz

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
   - **Name**: `nexus-helm-repo` (для momo-store) или `nexus-monitoring-repo` (для мониторинга)
   - **URL**: значение переменной `NEXUS_HELM_REPO` или `NEXUS_HELM_MONITORING_REPO`
   - **Username**: значение переменной `HELM_REPO_USERNAME`
   - **Password**: значение переменной `HELM_REPO_PASSWORD`
5. Нажмите **Connect** и проверьте подключение

#### 5.3 Создание Application для momo-store

1. В веб-интерфейсе ArgoCD нажмите **+ New App**
2. Заполните **General**:
   - **Application Name**: `momo-store`
   - **Project Name**: `default`
   - **Sync Policy**: `Automatic` (опционально)
3. Заполните **Source**:
   - **Repository URL**: выберите `nexus-helm-repo`
   - **Chart**: `momo-store`
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

### Основные сервисы приложения

| Сервис             | Endpoint                                       | Описание                            |
| ------------------ | ---------------------------------------------- | ----------------------------------- |
| **Frontend**       | `http://<nlb_external_ip>/momo-store`          | Веб-интерфейс приложения Momo Store |
| **Backend API**    | `http://<nlb_external_ip>/api`                 | REST API бэкенда приложения         |
| **Backend Health** | `http://<nlb_external_ip>/api/actuator/health` | Health check эндпоинт бэкенда       |

**Примеры доступа (подставьте свой IP вместо <nlb_external_ip>):**

- Главная страница: `http://<nlb_external_ip>/momo-store`
- API endpoint: `http://<nlb_external_ip>/api/products`
- Health check: `http://<nlb_external_ip>/api/actuator/health`

### Сервисы мониторинга

| Сервис         | Endpoint                        | Порт (NodePort) | Описание                                                  |
| -------------- | ------------------------------- | --------------- | --------------------------------------------------------- |
| **Prometheus** | `http://<nlb_external_ip>:9090` | 32090           | Сбор и хранение метрик                                    |
| **Grafana**    | `http://<nlb_external_ip>:3000` | 32300           | Визуализация метрик и дашборды (по умолчанию admin/admin) |
| **Loki**       | `http://<nlb_external_ip>:3100` | 32310           | Сбор и хранение логов                                     |

**Примечание**: Сервисы мониторинга доступны напрямую через NodePort, так как они не проходят через ingress-nginx (можно было бы через ingress, но так проще было сделать).

### GitOps и управление деплоем

| Сервис        | Endpoint                        | Порт (NodePort) | Описание                                     |
| ------------- | ------------------------------- | --------------- | -------------------------------------------- |
| **ArgoCD UI** | `http://<nlb_external_ip>:8080` | 32080           | Веб-интерфейс ArgoCD для управления деплоями |

### Kubernetes ресурсы

Все приложения развернуты в следующих namespace'ах (для справки):

| Namespace            | Приложения                               | Описание                         |
| -------------------- | ---------------------------------------- | -------------------------------- |
| `default`            | momo-store (frontend + backend)          | Основное приложение              |
| `monitoring`         | Prometheus, Grafana, Loki, Promtail      | Стек мониторинга                 |
| `argocd`             | ArgoCD компоненты                        | GitOps контроллер                |
| `kube-system`        | RKE2 системные компоненты, ingress-nginx | Системные сервисы                |
| `local-path-storage` | local-path-provisioner                   | Динамически выделенное хранилище |
