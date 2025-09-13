resource "yandex_iam_service_account" "terraform" {
  name        = "terraform"
  description = "Service account for Terraform"
}

resource "yandex_resourcemanager_folder_iam_member" "terraform-storage-role" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}
