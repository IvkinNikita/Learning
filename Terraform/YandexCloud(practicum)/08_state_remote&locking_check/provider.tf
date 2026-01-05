terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "> 0.100"
    }
  }
}

provider "yandex" {
  zone                     = "ru-central1-a"
  folder_id                = var.folder_id
  service_account_key_file = "../sa-key.json"
}

variable "folder_id" {
  description = "(Optional) - Yandex Cloud Folder ID where resources will be created."
  type        = string
}