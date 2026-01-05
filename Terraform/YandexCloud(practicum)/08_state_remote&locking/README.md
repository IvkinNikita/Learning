# Terraform: Remote State и Блокировка (State Locking) в Yandex Cloud

При совместной работе над инфраструктурой важно избегать одновременных изменений через Terraform — это может повредить **state-файл** и привести к несогласованности инфраструктуры.  
Решение: **удалённое хранение состояния** + **блокировка во время применения изменений**.

---

## 🔧 Как это работает

### 1. Remote Backend
State-файл (`terraform.tfstate`) хранится не локально, а в **объектном хранилище** (например, Yandex Object Storage — S3-совместимом).

### 2. State Locking
Чтобы запретить одновременный запуск `terraform apply`, Terraform использует **внешнее хранилище блокировок** — совместимое с **Amazon DynamoDB**.  
В Yandex Cloud это реализуется через **YDB в режиме совместимости с DynamoDB**.

> ⚠️ Object Storage **не поддерживает блокировки сам по себе**. Без DynamoDB/YDB — блокировка работать не будет.

---

## 🛠 Настройка в Yandex Cloud

### Шаг 1: Создать бакет в Object Storage
```bash
yc s3api create-bucket --bucket my-terraform-state --acl private
```

### Шаг 2: Создать DynamoDB-совместимую таблицу в YDB
Имя таблицы, например: `terraform-locks`.  
Она должна содержать **ключ `LockID` (строка)**.

Пример создания через CLI (предварительно создав YDB-базу в режиме serverless):
```bash
yc ydb table create --path terraform-locks \
  --attr 'Name=LockID,Type=String' \
  --key LockID \
  --endpoint <ydb-endpoint> \
  --database <database-id>
```

> Подробнее: [Документация Yandex Cloud — YDB в режиме DynamoDB](https://cloud.yandex.ru/docs/ydb/docapi/)

### Шаг 3: Настроить backend в Terraform

Файл `backend.tf`:
```hcl
terraform {
  backend "s3" {
    endpoint               = "storage.yandexcloud.net"
    region                 = "ru-central1"
    bucket                 = "my-terraform-state"
    key                    = "prod/terraform.tfstate"
    access_key             = var.yc_access_key
    secret_key             = var.yc_secret_key
    skip_region_validation = true
    skip_credentials_validation = true

    # Блокировка через YDB (DynamoDB-compatible)
    dynamodb_endpoint = "https://docapi.serverless.yandexcloud.net/ru-central1/b1g.../etn..."
    dynamodb_table    = "terraform-locks"
  }
}
```

> 🔐 Рекомендуется передавать `access_key`/`secret_key` через переменные или `~/.aws/credentials`, а не хардкодить.

---

## ✅ Проверка блокировки

1. Запусти `terraform apply` в первом терминале.
2. Пока он **ожидает подтверждения** (`Enter to apply`), запусти `terraform apply` во втором терминале.
3. Второй процесс **остановится с ошибкой** вида:
   ```
   Error acquiring the state lock
   ```
   или будет **ждать**, если используется флаг `-lock-timeout`.

После завершения первого `apply` блокировка снимается автоматически.

---

## 💸 Важно: удаляй ресурсы после практики

- Удалить бакет:
  ```bash
  yc s3api delete-bucket --bucket my-terraform-state
  ```
- Удалить таблицу в YDB:
  ```bash
  yc ydb table delete --path terraform-locks --endpoint <...> --database <...>
  ```

Иначе ресурсы будут тарифицироваться.

---

## 📚 Полезные ссылки

- [Terraform: S3 Backend (офиц.)](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Yandex Cloud: Object Storage (S3)](https://cloud.yandex.ru/docs/storage/)
- [Yandex Cloud: YDB DocAPI (DynamoDB-compatible)](https://cloud.yandex.ru/docs/ydb/docapi/)