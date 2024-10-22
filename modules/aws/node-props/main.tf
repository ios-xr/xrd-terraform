locals {
  constants = {
    "cloud-router" = {
      "m5.2xlarge" = {
        cpuset       = "2-3"
        hugepages_gb = 6
      }

      "m5n.2xlarge" = {
        cpuset       = "2-3"
        hugepages_gb = 6
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
  multi_numa_instance_types = {
    m5 = [
      "m5.16xlarge",
      "m5.24xlarge",
    ]

    m5n = [
      "m5n.16xlarge",
      "m5n.24xlarge",
    ]
  }
}

locals {
  cpus_to_cp_num_cpus = {
    0 = 0
    1 = 0
    2 = 0
    3 = 1
    4 = 2
    5 = 2
    6 = 2
    7 = 3
  }

  max_cp_num_cpus = 4
}

locals {
  minimal_cpuset = (
    data.aws_ec2_instance_type.this.default_cores < 4 ?
    null :
    "2-3"
  )
}

locals {
  # Is the given instance type multi NUMA?
  # This is null if we cannot recognize the instance type.
  is_multi_numa = try(
    contains(
      local.multi_numa_instance_types[split(".", var.instance_type)[0]],
      var.instance_type,
    ),
    null,
  )

  # End integer of the maximal CPU set.
  # This is null if there is no minimal CPU set, or if we cannot determine if
  # the instance type is multi NUMA.
  maximal_cpuset_end = (
    local.minimal_cpuset == null || local.is_multi_numa == null ?
    null :
    (
      local.is_multi_numa ?
      data.aws_ec2_instance_type.this.default_cores / 2 - 1 :
      data.aws_ec2_instance_type.this.default_cores - 1
    )
  )

  maximal_cpuset = (
    local.maximal_cpuset_end == null ?
    null :
    "2-${local.maximal_cpuset_end}"
  )
}

locals {
  cpuset = try(
    local.constants[var.use_case][var.instance_type].cpuset,
    (
      var.use_case == "minimal" ?
      local.minimal_cpuset :
      local.maximal_cpuset
    ),
  )

  cpuset_list = try(
    range(split("-", local.cpuset)[0], split("-", local.cpuset)[1] + 1),
    null,
  )
}

locals {
  cp_num_cpus = try(
    local.cpus_to_cp_num_cpus[length(local.cpuset_list)],
    local.max_cp_num_cpus,
  )

  isolated_cores_list = try(
    range(
      local.cpuset_list[0] + local.cp_num_cpus,
      local.cpuset_list[length(local.cpuset_list) - 1] + 1,
    ),
    null,
  )

  isolated_cores = try(
    "${local.isolated_cores_list[0]}-${local.isolated_cores_list[length(local.isolated_cores_list) - 1]}",
    null,
  )
}

locals {
  minimal_hugepages_gb = 6
  maximal_hugepages_gb = 6

  hugepages_gb = try(
    local.constants[var.use_case][var.instance_type].hugepages_gb,
    (
      var.use_case == "minimal" ?
      local.minimal_hugepages_gb :
      local.maximal_hugepages_gb
    )
  )
}
