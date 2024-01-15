output "cp_num_cpus" {
  description = "Number of control-plane CPUs"
  value       = local.cp_num_cpus
}

output "cpuset" {
  description = "CPU set"
  value       = local.cpuset
}

output "hugepages_gb" {
  description = "Dataplane hugepages, in GiB"
  value       = local.hugepages_gb
}

output "isolated_cores" {
  description = <<-EOT
  Dataplane CPU set.
  These cores must be isolated on the worker node.
  EOT
  value       = local.isolated_cores
}

output "isolated_cores_list" {
  description = "Isolated cores, as a list"
  value       = local.isolated_cores_list
}
