output "cpuset" {
  description = "XRd workload cpuset"
  value       = local.cpuset
}

output "cpuset_list" {
  description = "XRd workload cpuset, as a list of integers"
  value       = local.cpuset_list
}

output "hugepages_gb" {
  description = "XRd workload hugepages, in GiB"
  value       = local.hugepages_gb
}

output "isolated_cores" {
  description = "Worker node isolated cores"
  value       = local.isolated_cores
}

output "isolated_cores_list" {
  description = "Worker node isolated cores, as a list of integers"
  value       = local.isolated_cores_list
}
