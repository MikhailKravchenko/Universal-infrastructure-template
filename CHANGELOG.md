# История изменений

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).

## [Не указано]

### Добавлено

- Мульти-окружения (dev, staging, production) с отдельными namespace и values
- Чарт data-services (PostgreSQL, Redis, RabbitMQ, Kafka) на базе Bitnami
- Чарт external-secrets для синхронизации секретов из Yandex Lockbox
- Terraform: Lockbox (плейсхолдер секретов), Object Storage (S3)
- Стратегия бэкапов: скрипт pg-dump и CronJob для выгрузки в S3
- Документация: multi-env, secrets, backup
- ArgoCD Application по окружениям (app-dev, app-staging, app-production)

### Изменено

- Чарт приложения переименован в app-chart, параметризация по окружениям
- Backend: подключение к БД, RabbitMQ, Kafka, Redis, S3 через ConfigMap и Secret
- README расширен: архитектура, структура репо, переменные, устранение неполадок
- Лицензия MIT, раздел «Лицензия» в README
