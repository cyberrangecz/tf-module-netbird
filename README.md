<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.netbird](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.netbird](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.netbird_relay_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [random_id.netbird_encryption_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.netbird_owner_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.netbird_relay_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [kubernetes_secret.netbird_pat](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_contact"></a> [acme\_contact](#input\_acme\_contact) | Let's Encrypt contact email address (used when generating a certificate for an FQDN). | `string` | `""` | no |
| <a name="input_netbird_domain"></a> [netbird\_domain](#input\_netbird\_domain) | Full FQDN where NetBird is served (e.g. vpn.example.com). | `string` | n/a | yes |
| <a name="input_netbird_owner_email"></a> [netbird\_owner\_email](#input\_netbird\_owner\_email) | Email of the first NetBird owner user. Used only for the one-time /api/setup bootstrap. Defaults to admin@crczp | `string` | `null` | no |
| <a name="input_netbird_owner_name"></a> [netbird\_owner\_name](#input\_netbird\_owner\_name) | Display name of the first NetBird owner user (one-time bootstrap). | `string` | `"CRCZP Admin"` | no |
| <a name="input_netbird_pat_expiration_days"></a> [netbird\_pat\_expiration\_days](#input\_netbird\_pat\_expiration\_days) | Lifetime in days of the generated Personal Access Token (1-365). | `number` | `365` | no |
| <a name="input_netbird_pat_rotation_schedule"></a> [netbird\_pat\_rotation\_schedule](#input\_netbird\_pat\_rotation\_schedule) | Cron schedule for the in-cluster PAT rotation CronJob. | `string` | `"0 3 * * *"` | no |
| <a name="input_netbird_pat_rotator_image"></a> [netbird\_pat\_rotator\_image](#input\_netbird\_pat\_rotator\_image) | Container image (must provide curl and jq) used by the PAT bootstrap/rotation pods. | `string` | `"alpine:3.20"` | no |
| <a name="input_netbird_pat_secret_namespace"></a> [netbird\_pat\_secret\_namespace](#input\_netbird\_pat\_secret\_namespace) | Namespace where the PAT rotation-store Secret is created and read from. Defaults to the netbird namespace. If set to another namespace, that namespace must already exist. The Secret is not removed on destroy; a later deploy against fresh NetBird data overwrites it. | `string` | `null` | no |
| <a name="input_self_signed"></a> [self\_signed](#input\_self\_signed) | Use a self-signed certificate instead of Let's Encrypt for the NetBird FQDN. | `bool` | `false` | no |
| <a name="input_tls_private_key"></a> [tls\_private\_key](#input\_tls\_private\_key) | Base64 encoded TLS private key for the NetBird host. If not specified together with tls\_public\_key, a certificate is generated. | `string` | `""` | no |
| <a name="input_tls_public_key"></a> [tls\_public\_key](#input\_tls\_public\_key) | Base64 encoded TLS public key (certificate) for the NetBird host. If not specified together with tls\_private\_key, a certificate is generated. | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_netbird_owner_email"></a> [netbird\_owner\_email](#output\_netbird\_owner\_email) | Email of the first NetBird owner user. |
| <a name="output_netbird_owner_password"></a> [netbird\_owner\_password](#output\_netbird\_owner\_password) | Password of the first NetBird owner user |
| <a name="output_netbird_pat"></a> [netbird\_pat](#output\_netbird\_pat) | Personal Access Token of the first NetBird owner user, regenerated on every apply. |
| <a name="output_netbird_pat_user_id"></a> [netbird\_pat\_user\_id](#output\_netbird\_pat\_user\_id) | ID of the NetBird owner user the PAT belongs to. |
<!-- END_TF_DOCS -->
