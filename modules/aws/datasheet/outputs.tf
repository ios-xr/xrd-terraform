output "cpuset" {
  description = "XRd workload cpuset"
  value       = local.cpuset
}

output "hugepages_gb" {
  description = "XRd workload hugepages, in GiB"
  value       = local.hugepages_gb
}

output "isolated_cores" {
  description = "Worker node isolated cores"
  value       = local.isolated_cores
}
