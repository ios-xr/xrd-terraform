resource "aws_security_group" "ssh" {}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "random_uuid" "this" {}

module "key_pair" {
  source = "../../modules/aws/key-pair"

  key_name = random_uuid.this.id
  filename = "${abspath(path.root)}/${random_uuid.this.id}.pem"
}

output "key_name" {
  value = module.key_pair.key_name
}

output "key_pair_filename" {
  value = module.key_pair.filename
}
