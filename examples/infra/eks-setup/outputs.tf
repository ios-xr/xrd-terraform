output "key_name" {
  description = "Key pair name"
  value       = module.key_pair.key_name
}

output "bastion_id" {
  description = "ID of the bastion EC2 instance"
  value       = module.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion"
  value       = module.bastion.public_ip
}
