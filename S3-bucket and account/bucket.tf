resource "yandex_storage_bucket" "tf-bucket-s3" {
  bucket     = "tf-bucket-s3"
  acl        = "private"
  max_size   = 1073741824 # 1GB

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket_key.id
        sse_algorithm      = "aws:kms"
      }
    }
  }

  depends_on = [yandex_kms_symmetric_key.bucket_key]
}