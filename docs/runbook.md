# Runbook: реагирование на инциденты

Краткие сценарии и команды для типовых проблем. Подробнее об устранении неполадок — в [README](../README.md#устранение-неполадок).

## 1. ImagePullBackOff

**Симптом:** поды приложения в состоянии `ImagePullBackOff` или `ErrImagePull`.

**Действия:**

1. Проверьте наличие секрета для Docker Registry в нужном namespace:
   ```bash
   kubectl get secret docker-config-secret -n <namespace>
   ```
2. Убедитесь, что секрет имеет тип `kubernetes.io/dockerconfigjson`:
   ```bash
   kubectl get secret docker-config-secret -n <namespace> -o jsonpath='{.type}'
   ```
3. Проверьте логи пода:
   ```bash
   kubectl describe pod -n <namespace> -l app.kubernetes.io/name=app-backend
   ```
4. Проверьте доступность Registry с узла кластера (при необходимости) и корректность логина/пароля (или Deploy Token) в секрете. Для мульти-окружений секрет должен быть создан в каждом namespace (`dev`, `staging`, `production`).

**Создание секрета заново (если нужно):**
```bash
kubectl create secret docker-registry docker-config-secret \
  --docker-server=gitlab.praktikum-services.ru:5050 \
  --docker-username='<username>' \
  --docker-password='<token_or_password>' \
  --namespace=<namespace>
```

---

## 2. Backend не поднимается или не подключается к БД/очередям

**Симптом:** backend в CrashLoopBackOff или не видит PostgreSQL/RabbitMQ/Redis/Kafka.

**Действия:**

1. Проверьте, что заданы `backend.env.secretName` и `backend.env.configMapName` в values чарта приложения (или в параметрах ArgoCD Application).
2. Убедитесь, что Secret с паролями существует в том же namespace:
   ```bash
   kubectl get secret backend-secrets -n <namespace>
   ```
3. Проверьте ConfigMap с хостами (если создаётся чартом):
   ```bash
   kubectl get configmap backend-config -n <namespace> -o yaml
   ```
4. Имена сервисов должны совпадать с развёрнутым data-services в том же namespace: `postgresql`, `redis-master`, `rabbitmq`, `kafka`. Проверьте, что поды data-services запущены:
   ```bash
   kubectl get pods -n <namespace> -l app.kubernetes.io/name=postgresql
   kubectl get pods -n <namespace> -l app.kubernetes.io/name=redis
   ```
5. Логи backend:
   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=app-backend --tail=100
   ```

---

## 3. Проблемы External Secrets (Secret не создаётся)

**Симптом:** в namespace нет Secret `backend-secrets` или он пустой после установки external-secrets-config.

**Действия:**

1. Проверьте, что External Secrets Operator установлен в кластере:
   ```bash
   kubectl get pods -n external-secrets
   ```
2. Проверьте статус ExternalSecret в целевом namespace:
   ```bash
   kubectl get externalsecret -n <namespace>
   kubectl describe externalsecret <name> -n <namespace>
   ```
3. Убедитесь, что в namespace `external-secrets` есть Secret с авторизованным ключом Yandex (имя и ключ должны совпадать с values чарта external-secrets-config: по умолчанию `yc-lockbox-auth`, ключ `authorized-key`):
   ```bash
   kubectl get secret yc-lockbox-auth -n external-secrets
   ```
4. Проверьте логи оператора ESO:
   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50
   ```
5. В values чарта external-secrets-config проверьте `lockboxSecretId` (ID секрета в Yandex Lockbox) и список `targetNamespaces`.

---

## 4. ArgoCD OutOfSync или ошибка при синхронизации

**Симптом:** Application в ArgoCD в состоянии OutOfSync или с ошибкой синхронизации.

**Действия:**

1. Проверьте, что в Application указана версия чарта, которая реально есть в Nexus (например, `0.1.3-pipeline<ID>`).
2. Убедитесь, что Helm-репозиторий подключён в ArgoCD (Settings → Repositories) и учётные данные верные (`HELM_REPO_USERNAME`, `HELM_REPO_PASSWORD`).
3. Проверьте логи синхронизации в веб-интерфейсе ArgoCD или:
   ```bash
   kubectl get application -n argocd
   argocd app get <app-name>  # если установлен CLI
   ```
4. При ошибке «chart not found» обновите индекс репозитория в ArgoCD или укажите точную версию чарта после успешной публикации в GitLab CI.

---

## 5. Проверка бэкапов и восстановление

**Что проверить:**

- CronJob дампа PostgreSQL в namespace `backup` выполняется по расписанию (например, ежедневно в 02:00).
- Файлы дампов появляются в S3 в пути `backups/postgres/`.

**Восстановление PostgreSQL из дампа:** пошагово описано в [backup.md](backup.md#восстановление-postgresql-из-дампа): скачать нужный файл из S3 и выполнить `gunzip -c ... | psql ...` или восстановление через под в кластере.

---

## Связанная документация

| Документ | Содержание |
|----------|------------|
| [README](../README.md#устранение-неполадок) | Краткий список неполадок |
| [backup.md](backup.md) | Стратегия бэкапов, восстановление |
| [secrets.md](secrets.md) | Lockbox, ESO, добавление ключей |
| [multi-env.md](multi-env.md) | Окружения, values, ArgoCD |
