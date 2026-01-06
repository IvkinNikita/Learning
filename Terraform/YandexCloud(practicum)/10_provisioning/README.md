# Провижинг в Terraform

Провижинг (provisioning) в Terraform — это процесс **настройки и конфигурации ресурсов после их создания**, но до завершения применения конфигурации. Он используется, когда встроенных возможностей провайдера (например, `user_data` в cloud-инстансах) недостаточно.

> ⚠️ **Важно**: Провижинеры — **последнее средство**. По возможности используй **cloud-init**, **образы с предустановленной конфигурацией** (Packer), **Kubernetes Jobs**, **Ansible через внешний CI/CD** и т.п.

---

## Встроенные провижинеры

### `local-exec`
Выполняет команду **на машине, где запущен Terraform**.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command = "echo ${aws_instance.web.public_ip} > public_ip.txt"
  }
}
```

### `remote-exec`
Выполняет команды **на удалённой машине** через SSH или WinRM.

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo apt-get update",
    "sudo apt-get install -y nginx"
  ]
}
```

### `file`
Копирует файлы или директории **с локальной машины на удалённый ресурс**.

```hcl
provisioner "file" {
  source      = "app-config.yaml"
  destination = "/etc/myapp/config.yaml"
}
```

Провижинер `file` требует настроенного соединения, так же как и `remote-exec`.

---

## Блок `connection`: как обеспечить доступ к удалённой машине

Провижинеры `remote-exec` и `file` работают только при наличии соединения с целевой системой. Это настраивается с помощью блока **`connection`** внутри ресурса.

Поддерживаются два типа соединений:
- **`ssh`** — для Linux и других Unix-подобных систем
- **`winrm`** — для Windows

### Пример: SSH-соединение (Linux)

```hcl
resource "yandex_compute_instance" "vm" {
  # ... конфигурация ВМ

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.network_interface.0.nat_ip_address
    port        = 22
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/setup.sh", "sudo /tmp/setup.sh"]
  }
}
```

### Пример: WinRM-соединение (Windows)

```hcl
resource "aws_instance" "win" {
  ami           = "ami-windows-server-2022"
  instance_type = "t3.medium"

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = var.admin_password
    host     = self.public_ip
    port     = 5985
    https    = false
    timeout  = "10m"
  }

  provisioner "remote-exec" {
    inline = ["powershell.exe Install-WindowsFeature -Name Web-Server"]
  }
}
```

Важно:
- Убедитесь, что брандмауэр разрешает подключение (порт 22 для SSH, 5985/5986 для WinRM).
- Учётные данные (ключи или пароли) должны быть доступны Terraform.
- ВМ должна быть полностью запущена и иметь сетевую доступность до начала работы провижинеров.

---

## Альтернатива провижинерам: cloud-init

**cloud-init** — это стандартный механизм инициализации Linux-систем в облачных средах. Он запускается автоматически при первой загрузке ВМ и применяет конфигурацию, переданную через `user_data`.

### Как использовать cloud-init в Terraform

1. Создайте YAML-файл с конфигурацией (часто в виде шаблона `.tftpl`).
2. Передайте его в поле `user_data` (или аналог) при создании ВМ.

```hcl
resource "yandex_compute_instance" "web" {
  # ...

  metadata = {
    user_data = templatefile("cloud-init.yaml.tftpl", {
      hostname = "web01"
    })
  }
}
```

Пример содержимого `cloud-init.yaml.tftpl`:

```yaml
#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: "Hello from cloud-init!"
runcmd:
  - systemctl restart nginx
```

### Преимущества cloud-init перед провижинерами

- **Идемпотентность**: cloud-init запускается один раз при первой загрузке и не зависит от повторных `terraform apply`.
- **Надёжность**: работает на раннем этапе загрузки, не требует запущенного SSH-демона на момент вызова из Terraform.
- **Безопасность**: не требует открытия SSH-доступа к ВМ для машины, где запущен Terraform.
- **Переносимость**: поддерживается большинством публичных облаков и стандартных образов (Ubuntu, Debian, CentOS и др.).
- **Логирование**: все действия логируются внутри самой ВМ (`/var/log/cloud-init.log`), что упрощает отладку.
- **Декларативность**: конфигурация становится частью описания инфраструктуры, а не внешним побочным эффектом.

В отличие от провижинеров, cloud-init:
- не нарушает принцип «immutable infrastructure»;
- не зависит от состояния сети между Terraform и ВМ;
- не оставляет «слепых зон» в управлении состоянием.

> ✅ **Рекомендация**: Используйте `cloud-init` для всей начальной настройки Linux-машин. Провижинеры оставляйте только для специфических задач, например:
> - запись информации о ВМ в локальный файл (`local-exec`);
> - сценарии, которые невозможны без прямого взаимодействия с уже полностью загруженной системой.

---

## Заключение

Провижинеры в Terraform — мощный, но рискованный инструмент. Они легко ломают идемпотентность и усложняют отладку. В большинстве случаев их можно и нужно заменить на:
- **cloud-init** — для Linux в облаке,
- **sysprep + user_data или PowerShell-скрипты** — для Windows,
- **внешние системы конфигурации** (Ansible, Chef и др.) — для сложной логики.

Используйте провижинеры только тогда, когда других вариантов действительно нет.