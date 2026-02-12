#!/usr/bin/env sh
# Дамп PostgreSQL и загрузка в S3-совместимое хранилище (Yandex Object Storage).
# Использование: передайте переменные окружения PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE,
# S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY (или AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY).
# В K8s: запуск из CronJob с secretRef/env для паролей.

set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DUMP_FILE="/tmp/pg_dump_${TIMESTAMP}.sql.gz"

pg_dump -h "${PGHOST:-postgresql}" -p "${PGPORT:-5432}" -U "${PGUSER:-postgres}" -d "${PGDATABASE:-app_store}" \
  | gzip -c > "$DUMP_FILE"

if [ -n "$S3_ENDPOINT" ] && [ -n "$S3_BUCKET" ]; then
  # Используем AWS CLI-совместимые переменные для s3cmd/minio client или aws cli
  export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY:-$AWS_ACCESS_KEY_ID}"
  export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY:-$AWS_SECRET_ACCESS_KEY}"
  export AWS_DEFAULT_REGION="${S3_REGION:-ru-central1}"
  # Пример с aws cli (endpoint для Yandex: https://storage.yandexcloud.net)
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp "$DUMP_FILE" "s3://${S3_BUCKET}/backups/postgres/${TIMESTAMP}.sql.gz" --endpoint-url "${S3_ENDPOINT}"
  else
    echo "aws cli not found; upload $DUMP_FILE to s3://${S3_BUCKET}/backups/postgres/ manually"
  fi
fi

rm -f "$DUMP_FILE"
echo "Backup completed: ${TIMESTAMP}.sql.gz"
