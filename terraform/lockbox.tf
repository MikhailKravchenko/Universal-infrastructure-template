# Lockbox — секрет для External Secrets Operator (опционально)

resource "yandex_lockbox_secret" "backend_secrets" {
  count       = var.lockbox_create_placeholder ? 1 : 0
  name        = "backend-secrets"
  description = "Placeholder for backend app secrets (DB, RabbitMQ, Redis, S3). Add payload via Console or CLI."
  folder_id   = var.folder_id
  labels      = {}
}

# Версия секрета с плейсхолдером (замените на реальные значения через Console или yc lockbox secret update)
resource "yandex_lockbox_secret_version" "backend_secrets_v1" {
  count     = var.lockbox_create_placeholder ? 1 : 0
  secret_id = yandex_lockbox_secret.backend_secrets[0].id
  entries {
    key        = "SPRING_DATASOURCE_USERNAME"
    text_value = "postgres"
  }
  entries {
    key        = "SPRING_DATASOURCE_PASSWORD"
    text_value = "CHANGE_ME"
  }
  entries {
    key        = "SPRING_RABBITMQ_USERNAME"
    text_value = "user"
  }
  entries {
    key        = "SPRING_RABBITMQ_PASSWORD"
    text_value = "CHANGE_ME"
  }
  entries {
    key        = "SPRING_DATA_REDIS_PASSWORD"
    text_value = "CHANGE_ME"
  }
  entries {
    key        = "S3_ACCESS_KEY"
    text_value = ""
  }
  entries {
    key        = "S3_SECRET_KEY"
    text_value = ""
  }
}
