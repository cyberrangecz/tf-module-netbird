locals {
  netbird_owner_email = coalesce(
    var.netbird_owner_email, "admin@crczp"
  )
  netbird_pat_secret_name = "netbird-pat"
  netbird_pat_secret_namespace = coalesce(
    var.netbird_pat_secret_namespace, kubernetes_namespace.netbird.metadata[0].name
  )
}

resource "random_password" "netbird_relay_secret" {
  length  = 32
  special = false
}

resource "random_password" "netbird_owner_password" {
  length  = 32
  special = true
}

resource "random_id" "netbird_encryption_key" {
  byte_length = 32
}

resource "kubernetes_namespace" "netbird" {
  metadata {
    name = "netbird"
  }
}

resource "kubernetes_secret" "netbird_relay_secret" {
  metadata {
    name      = "netbird-relay-secret"
    namespace = kubernetes_namespace.netbird.metadata[0].name
  }

  data = {
    secret = random_password.netbird_relay_secret.result
  }
}

resource "helm_release" "netbird" {
  name             = "netbird"
  chart            = "${path.module}/helm/netbird"
  namespace        = kubernetes_namespace.netbird.metadata[0].name
  create_namespace = false

  set = [{
    name  = "headHost"
    value = var.head_host
    },
    {
      name  = "encryptionKey"
      value = random_id.netbird_encryption_key.b64_std
    },
    {
      name  = "server.relayAuthSecret"
      value = random_password.netbird_relay_secret.result
    },
    {
      name  = "pat.secretName"
      value = local.netbird_pat_secret_name
    },
    {
      name  = "pat.secretNamespace"
      value = local.netbird_pat_secret_namespace
    },
    {
      name  = "pat.tokenName"
      value = "crczp-managed"
    },
    {
      name  = "pat.expireDays"
      value = tostring(var.netbird_pat_expiration_days)
    },
    {
      name  = "pat.image"
      value = var.netbird_pat_rotator_image
    },
    {
      name  = "pat.rotation.schedule"
      value = var.netbird_pat_rotation_schedule
    },
    {
      name  = "pat.owner.email"
      value = local.netbird_owner_email
    },
    {
      name  = "pat.owner.name"
      value = var.netbird_owner_name
    },
    {
      name  = "subdomain"
      value = var.netbird_subdomain
    },
    {
      name  = "tls.selfSigned"
      value = var.self_signed
    },
    {
      name  = "tls.publicKey"
      value = var.tls_public_key
    },
    {
      name  = "tls.acmeContact"
      value = var.acme_contact
    }
  ]

  set_sensitive = [{
    name  = "pat.owner.password"
    value = random_password.netbird_owner_password.result
    },
    {
      name  = "tls.privateKey"
      value = var.tls_private_key
  }]

  depends_on = [
    kubernetes_secret.netbird_relay_secret
  ]
}

data "kubernetes_secret" "netbird_pat" {
  metadata {
    name      = local.netbird_pat_secret_name
    namespace = local.netbird_pat_secret_namespace
  }

  depends_on = [helm_release.netbird]
}
