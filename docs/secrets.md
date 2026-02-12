# Управление секретами (External Secrets + Yandex Lockbox)

Пароли и ключи не хранятся в Git. Они хранятся в Yandex Lockbox; в кластер попадают через External Secrets Operator (ESO), который создаёт обычные Kubernetes Secret из данных Lockbox.

## 1. Создание секрета в Lockbox

### Через Terraform

В [../terraform/](../terraform/) при `lockbox_create_placeholder = true` создаётся секрет Lockbox с плейсхолдерами. После `terraform apply` выведите ID:

```bash
terraform output lockbox_secret_id
```

Реальные значения ключей нужно задать в консоли Yandex Cloud (Lockbox) или через CLI:

```bash
yc lockbox secret version add --id <secret-id> --payload "[{\"key\":\"SPRING_DATASOURCE_PASSWORD\",\"text_value\":\"your-db-password\"}, ...]"
```

### Вручную в консоли Yandex

1. Создайте секрет в разделе Lockbox.
2. Добавьте версию с ключами: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`, `SPRING_DATA_REDIS_PASSWORD`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` (по необходимости).
3. Скопируйте ID секрета — он понадобится для ESO.

## 2. Доступ ESO к Lockbox

ESO обращается к Lockbox от имени сервисного аккаунта Yandex Cloud. Нужно:

1. Создать сервисный аккаунт в каталоге.
2. Выдать ему роль `lockbox.payloadViewer` на секрет (или на каталог).
3. Создать авторизованный ключ для этого сервисного аккаунта и сохранить в файл `authorized-key.json`.
4. Создать в Kubernetes Secret с этим ключом в namespace `external-secrets`:

```bash
kubectl create namespace external-secrets
kubectl create secret generic yc-lockbox-auth -n external-secrets --from-file=authorized-key=authorized-key.json
```

Имя секрета и ключа файла должны совпадать с values чарта external-secrets-config (`ycAuthSecretName`, `ycAuthSecretKey`).

## 3. Установка External Secrets Operator

ESO устанавливается один раз в кластер (не из этого репозитория):

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true
```

## 4. Установка конфигурации (SecretStore + ExternalSecret)

Чарт [../external-secrets-chart/](../external-secrets-chart/) создаёт:

- **ClusterSecretStore** `yandex-lockbox` — подключается к Lockbox через секрет `yc-lockbox-auth`.
- **ExternalSecret** в каждом из `targetNamespaces` (dev, staging, production) — синхронизирует секрет из Lockbox в K8s Secret `backend-secrets`.

Перед установкой в `values.yaml` укажите:

- `lockboxSecretId` — ID секрета в Lockbox (из terraform output или консоли).
- `ycAuthSecretName` / `ycAuthSecretKey` — имя K8s Secret и ключа с авторизованным ключом (по умолчанию `yc-lockbox-auth`, `authorized-key`).
- `targetNamespaces` — список namespace, куда синхронизировать `backend-secrets`.

Установка:

```bash
helm upgrade --install external-secrets-config ./external-secrets-chart -n external-secrets -f external-secrets-chart/values.yaml
```

После синхронизации в каждом target namespace появится Secret `backend-secrets` с ключами из Lockbox.

## 5. Подключение backend к секрету

В values чарта приложения (app) или в ArgoCD Application задайте для backend:

```yaml
backend:
  env:
    secretName: backend-secrets
    configMapName: backend-config
    dataServices:
      postgresqlHost: postgresql
      rabbitmqHost: rabbitmq
      kafkaBootstrapServers: kafka:9092
      redisHost: redis-master
      s3Endpoint: https://storage.yandexcloud.net
      s3Bucket: your-bucket
```

Чарт backend создаст ConfigMap `backend-config` с несекретными переменными и подключит Pod к `envFrom` из Secret `backend-secrets` и ConfigMap `backend-config`.

## Добавление нового ключа в Lockbox

1. В консоли Lockbox добавьте новую версию секрета с дополнительным ключом (или обновите существующую версию).
2. В манифестах ExternalSecret в [../external-secrets-chart/templates/externalsecret.yaml](../external-secrets-chart/templates/externalsecret.yaml) добавьте блок в `data`:

```yaml
- secretKey: NEW_KEY_NAME
  remoteRef:
    key: <lockbox-secret-id>
    property: NEW_KEY_NAME
```

3. Переустановите или обновите чарт external-secrets-config. ESO подхватит новый ключ при следующей синхронизации (refreshInterval).
