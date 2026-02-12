# Мульти-окружения (dev / staging / production)

В одном кластере используются отдельные namespace для каждого окружения: `dev`, `staging`, `production`. Один и тот же набор Helm-чартов деплоится в разные namespace с разными values.

## Namespace и квоты

Манифесты namespace с ResourceQuota и LimitRange лежат в [../kubernetes/namespaces/](../kubernetes/namespaces/):

- `dev-namespace.yaml` — dev, лимиты ниже (например 2 CPU, 4 Gi memory)
- `staging-namespace.yaml` — staging
- `production-namespace.yaml` — production, более высокие квоты

Применить вручную (если не создаются через ArgoCD):

```bash
kubectl apply -f kubernetes/namespaces/dev-namespace.yaml
kubectl apply -f kubernetes/namespaces/staging-namespace.yaml
kubectl apply -f kubernetes/namespaces/production-namespace.yaml
```

## Values по окружениям

### Приложение (app)

В [../app-chart/](../app-chart/) есть файлы:

- `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`

При установке через Helm можно передать нужный файл:

```bash
helm upgrade --install app-dev ./app-chart -f app-chart/values-dev.yaml -n dev
```

### data-services

В [../data-services-chart/](../data-services-chart/):

- `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`

Пример:

```bash
helm upgrade --install data-services ./data-services-chart -f data-services-chart/values-dev.yaml -n dev
```

## ArgoCD

Примеры Application для приложения по окружениям: [../argocd/applications/](../argocd/applications/).

- **app-dev** — destination namespace `dev`, параметры `environment: dev`
- **app-staging** — namespace `staging`
- **app-production** — namespace `production`

В ArgoCD при создании Application укажите:

1. **Source**: репозиторий Helm (Nexus), chart `app`, нужная версия.
2. **Destination**: Cluster `https://kubernetes.default.svc`, Namespace — `dev`, `staging` или `production`.
3. **Helm**: в Parameters задайте переопределения (например `environment`, `backend.replicaCount`) или подключите values из Git, если репозиторий приложения добавлен в ArgoCD как Git-источник с файлами values-*.yaml.

Для полного использования values из репозитория можно добавить в ArgoCD второй источник (Git) с путём к `values-dev.yaml` и т.д., либо хранить values в том же Helm-репозитории, если Nexus это поддерживает.

## Порядок деплоя по окружениям

1. Создать namespace (если ещё не созданы).
2. Установить data-services в нужный namespace (PostgreSQL, Redis, RabbitMQ, Kafka).
3. Настроить секреты (backend-secrets) в этом namespace — вручную или через External Secrets.
4. Установить приложение (app) с указанием `backend.env.secretName` и `backend.env.configMapName` (и при необходимости dataServices).
5. Повторить для каждого окружения (dev, staging, production).
