locals {
  constants = {
    "cloud-router" = {
      "m5.2xlarge" = {
        cpuset       = "2-3"
        hugepages_gb = 4
      }

      "m5n.2xlarge" = {
        cpuset       = "2-3"
        hugepages_gb = 4
      }

      "m5.24xlarge" = {
        cpuset       = "12-23"
        hugepages_gb = 6
      }

      "m5n.24xlarge" = {
        cpuset       = "12-23"
        hugepages_gb = 6
      }
    }
  }
}

locals {
  minimal_cpuset = (
    data.aws_ec2_instance_type.this.default_cores < 4 ?
    null :
    "2-3"
  )
}

locals {
  instance_type_to_multi_numa_floor = {
    "m5"  = 32
    "m5n" = 32
  }

  multi_numa_floor = try(
    local.instance_type_to_multi_numa_floor[split(".", var.instance_type)[0]],
    null,
  )

  maximal_cpuset_ceil = (
    local.minimal_cpuset == null || local.multi_numa_floor == null ?
    null :
    (
      data.aws_ec2_instance_type.this.default_cores < local.multi_numa_floor ?
      data.aws_ec2_instance_type.this.default_cores - 1 :
      data.aws_ec2_instance_type.this.default_cores / 2 - 1
    )
  )

  maximal_cpuset = (
    local.maximal_cpuset_ceil == null ?
    null :
    "2-${local.maximal_cpuset_ceil}"
  )
}

locals {
  cpuset = try(
    local.constants[var.use_case][var.instance_type].cpuset,
    (
      var.use_case == "minimal" ?
      local.minimal_cpuset :
      local.maximal_cpuset
    )
  )

  cpuset_list = (
    local.cpuset == null ?
    null :
    range(split("-", local.cpuset)[0], split("-", local.cpuset)[1] + 1)
  )
}

locals {
  cp_core_count = (
    local.cpuset_list == null ?
    null :
    (
      length(local.cpuset_list) < 3 ?
      0 : # special case where CP and DP share a core
      (
        length(local.cpuset_list) < 4 ?
        1 :
        (
          length(local.cpuset_list) < 7 ?
          2 :
          (
            length(local.cpuset_list) < 8 ?
            3 :
            4
          )
        )
      )
    )
  )

  isolated_cores_list = (
    local.cpuset_list == null ?
    null :
    range(local.cpuset_list[0] + local.cp_core_count, local.cpuset_list[length(local.cpuset_list) - 1] + 1)
  )

  isolated_cores = try(
    "${local.isolated_cores_list[0]}-${local.isolated_cores_list[length(local.isolated_cores_list) - 1]}",
    null,
  )
}

locals {
  minimal_hugepages_gb = 6
  maximal_hugepages_gb = 8

  hugepages_gb = try(
    local.constants[var.use_case][var.instance_type].hugepages_gb,
    (
      var.use_case == "minimal" ?
      local.minimal_hugepages_gb :
      local.maximal_hugepages_gb
    )
  )
}
