# Object Storage (S3-совместимое) для приложения и бэкапов

resource "yandex_iam_service_account" "storage_sa" {
  count        = var.create_storage_bucket && var.storage_bucket_name != "" ? 1 : 0
  name         = "storage-sa-${replace(var.storage_bucket_name, "_", "-")}"
  description  = "Service account for Object Storage bucket ${var.storage_bucket_name}"
  folder_id    = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "storage_sa_editor" {
  count      = var.create_storage_bucket && var.storage_bucket_name != "" ? 1 : 0
  folder_id  = var.folder_id
  role       = "storage.editor"
  member     = "serviceAccount:${yandex_iam_service_account.storage_sa[0].id}"
}

resource "yandex_iam_service_account_static_access_key" "storage_sa_key" {
  count           = var.create_storage_bucket && var.storage_bucket_name != "" ? 1 : 0
  service_account_id = yandex_iam_service_account.storage_sa[0].id
  description        = "Static key for S3 bucket ${var.storage_bucket_name}"
}

resource "yandex_storage_bucket" "app_bucket" {
  count       = var.create_storage_bucket && var.storage_bucket_name != "" ? 1 : 0
  bucket      = var.storage_bucket_name
  folder_id   = var.folder_id
  access_key  = yandex_iam_service_account_static_access_key.storage_sa_key[0].access_key
  secret_key  = yandex_iam_service_account_static_access_key.storage_sa_key[0].secret_key
  max_size    = 1073741824 # 1 GB, при необходимости увеличьте
  anonymous_access_flags {
    read = false
    list = false
  }
}
