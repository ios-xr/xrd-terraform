locals {
  value = try(
    local.constants[var.use_case][var.instance_type],
    local.constants[var.use_case]["default"],
  )
}

output "cpuset" {
  description = "XRd workload cpuset"
  value       = local.value.cpuset
}

output "hugepages_gb" {
  description = "XRd workload hugepages, in GiB"
  value       = local.value.hugepages_gb
}

output "isolated_cores" {
  description = "Worker node isolated cores"
  value       = local.value.isolated_cores
}
