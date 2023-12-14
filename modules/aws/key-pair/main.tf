resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = trimspace(tls_private_key.this.public_key_openssh)
}

resource "local_sensitive_file" "this" {
  content         = trimspace(tls_private_key.this.private_key_pem)
  filename        = var.filename
  file_permission = "0400"
}
