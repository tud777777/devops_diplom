resource "yandex_kms_symmetric_key" "bucket_key" {
  name              = "bucket_key"
  description       = "KMS ключ"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 1 год
}