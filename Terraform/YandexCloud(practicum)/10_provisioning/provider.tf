# Объявление провайдера
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    random = {
      source = "hashicorp/random"
    }
    
  }
  required_version = ">= 1.00"
}

provider "yandex" {
  zone                     = "ru-central1-a"
  folder_id                = var.folder_id
  service_account_key_file = "../sa-key.json"
}

provider "random" {
}

provider "aws" {
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}