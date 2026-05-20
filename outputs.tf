output "netbird_pat" {
  description = "Personal Access Token of the first NetBird owner user, regenerated on every apply."
  value       = data.kubernetes_secret.netbird_pat.data["pat"]
  sensitive   = true
}

output "netbird_pat_user_id" {
  description = "ID of the NetBird owner user the PAT belongs to."
  value       = data.kubernetes_secret.netbird_pat.data["user_id"]
}

output "netbird_owner_email" {
  description = "Email of the first NetBird owner user."
  value       = local.netbird_owner_email
}

output "netbird_owner_password" {
  description = "Password of the first NetBird owner user"
  value       = random_password.netbird_owner_password.result
  sensitive   = true
}
