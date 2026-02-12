# Стратегия бэкапов

## Что бэкапится

| Объект | Как | Где хранится |
|--------|-----|--------------|
| **PostgreSQL** | Дамп (pg_dump) по расписанию | S3 (Yandex Object Storage), путь `backups/postgres/` |
| **Конфигурация** | Git (Helm, ArgoCD) | Уже в репозитории |
| **Секреты** | Lockbox | Yandex Lockbox; экспорт списка ключей — в runbook при необходимости |
| **Образы приложения** | Registry | GitLab Registry / Nexus; восстановление через передеплой |

## PostgreSQL → S3

### Скрипт

В [../backup/pg-dump-s3.sh](../backup/pg-dump-s3.sh) — пример скрипта: дамп в сжатый файл и загрузка в S3. Переменные окружения: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`.

### CronJob в Kubernetes

В [../backup/cronjob-postgres-backup.yaml](../backup/cronjob-postgres-backup.yaml) приведён пример:

- Namespace `backup`
- CronJob `postgres-backup-to-s3` (расписание по умолчанию: ежедневно в 02:00)
- Secret `backup-secrets` — `PGPASSWORD`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`
- ConfigMap `backup-config` — `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE`, `S3_ENDPOINT`, `S3_BUCKET`

Перед применением:

1. Создайте бакет в Object Storage (через Terraform: `create_storage_bucket = true`, `storage_bucket_name = "my-backup-bucket"`) или используйте существующий.
2. Создайте Secret `backup-secrets` в namespace `backup` и при необходимости обновите `backup-config` (PGHOST должен быть доступен из Pod — например `postgresql.production.svc.cluster.local` для БД в namespace production).

Применить пример:

```bash
kubectl apply -f backup/cronjob-postgres-backup.yaml
kubectl create secret generic backup-secrets -n backup \
  --from-literal=PGPASSWORD=... \
  --from-literal=S3_ACCESS_KEY=... \
  --from-literal=S3_SECRET_KEY=...
```

### Частота и хранение

- Рекомендуется: минимум раз в сутки (CronJob уже настроен на 02:00).
- В бакете можно включить lifecycle (например удаление объектов старше 30 дней) в Terraform или в консоли Yandex.

## Восстановление PostgreSQL из дампа

1. Скачайте нужный файл из S3 (например `backups/postgres/20250115-020001.sql.gz`).
2. Восстановите в БД:

```bash
gunzip -c 20250115-020001.sql.gz | psql -h <pg-host> -U postgres -d app_store
```

Или загрузите в под с PostgreSQL и выполните там:

```bash
kubectl cp 20250115-020001.sql.gz production/postgresql-0:/tmp/
kubectl exec -it production/postgresql-0 -- gunzip -c /tmp/20250115-020001.sql.gz | psql -U postgres -d app_store
```

## S3-бакет через Terraform

В [../terraform/](../terraform/) при необходимости создаётся бакет и статические ключи доступа:

- `create_storage_bucket = true`
- `storage_bucket_name = "уникальное-имя-бакета"`

После `terraform apply` ключи выводятся в `terraform output storage_s3_access_key` и `storage_s3_secret_key` (sensitive). Сохраните их в Lockbox (ключи `S3_ACCESS_KEY`, `S3_SECRET_KEY`) или в Secret `backup-secrets` для CronJob.
