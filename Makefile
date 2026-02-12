# Makefile для типовых операций с инфраструктурой.
# Использование: make <цель>. Секреты и переменные задаются отдельно (terraform.tfvars, env).

.PHONY: help terraform-init terraform-plan terraform-apply helm-lint helm-package-app \
	helm-package-monitoring helm-package-data-services helm-package-external-secrets \
	kubectl-apply-namespaces

help:
	@echo "Доступные цели:"
	@echo "  terraform-init              — инициализация Terraform (terraform/)"
	@echo "  terraform-plan              — план изменений инфраструктуры"
	@echo "  terraform-apply             — применение изменений Terraform"
	@echo "  helm-lint                   — проверка всех Helm-чартов (lint)"
	@echo "  helm-package-app            — упаковка чарта app локально"
	@echo "  helm-package-monitoring     — упаковка чарта monitoring локально"
	@echo "  helm-package-data-services  — упаковка чарта data-services локально"
	@echo "  helm-package-external-secrets — упаковка чарта external-secrets-config локально"
	@echo "  kubectl-apply-namespaces    — применить манифесты namespace (dev, staging, production)"

terraform-init:
	cd terraform && terraform init

terraform-plan:
	cd terraform && terraform plan

terraform-apply:
	cd terraform && terraform apply

helm-lint:
	cd app-chart && helm dependency update && helm lint .
	cd monitoring-chart && helm dependency update && helm lint .
	helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
	cd data-services-chart && helm dependency update && helm lint .
	cd external-secrets-chart && helm lint .

helm-package-app:
	cd app-chart && helm dependency update && helm package .

helm-package-monitoring:
	cd monitoring-chart && helm dependency update && helm package .

helm-package-data-services:
	helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
	cd data-services-chart && helm dependency update && helm package .

helm-package-external-secrets:
	cd external-secrets-chart && helm package .

kubectl-apply-namespaces:
	kubectl apply -f kubernetes/namespaces/
