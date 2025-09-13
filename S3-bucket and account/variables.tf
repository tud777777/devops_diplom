variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "default_zone" {
  description = "Default zone"
  type = string
  default = "ru-central1-a"
}