# `locals` и `outputs` в Terraform

**`locals`** — это внутренние переменные, которые вы используете **только внутри** конфигурации, чтобы не дублировать код. Они не задаются извне и ссылаются через `local.name`.

```hcl
locals {
  name = "app-${var.env}"
}
```

**`outputs`** — это значения, которые **выводятся наружу** после `terraform apply`. Они позволяют увидеть IP, URL, ID и другую полезную информацию или передать её в другие модули.

```hcl
output "ip" {
  value = yandex_compute_instance.vm.network_interface[0].ip_address
}
```

`locals` — для удобства внутри кода, `outputs` — для доступа к результатам снаружи.