# The interface handling here is non-ideal but is the best we can do.
#
# Ideally would cold-attach networking interfaces (i.e. attach when
# the instances is initially launched) but the AWS CLI has some limitations
# reflected in the Terraform resource that means this doesn't work:
#  - Interfaces end up with the default security group.
#  - Can't turn off source_dest_check
#
# As such, have to host-attach these after the EC2 instance has been launched.
# This comes with its own drawback - no support for delete_on_termination,
# which means that we have to wait for all the network interfaces to
# be destroyed before destroying the instance on teardown, which can
# take a few minutes.

locals {
  ami_generated_by_packer = [
    for k, v in data.aws_ami.this.tags : true
    if k == "Generated_By" && v == "xrd-packer"
  ]

  is_xrd_ami = coalesce(
    var.is_xrd_ami,
    length(local.ami_generated_by_packer) > 0,
  )

  # We need to lookup isolated_cores if it is not provided, and if we cannot
  # derive it from the provided CPU set and number of CP CPUs.
  isolated_cores_lookup_required = (
    var.isolated_cores == null &&
    (var.xrd_vr_cpuset == null || var.xrd_vr_cp_num_cpus == null)
  )

  node_props_required = (
    local.is_xrd_ami &&
    (var.hugepages_gb == null || local.isolated_cores_lookup_required)
  )
}

module "node_props" {
  source = "../node-props"

  count = local.node_props_required ? 1 : 0

  instance_type = var.instance_type
  use_case      = "maximal"
}

locals {
  hugepages_gb = try(
    coalesce(var.hugepages_gb, try(module.node_props[0].hugepages_gb, null)),
    null,
  )

  xrd_vr_cpuset = (
    var.isolated_cores != null ?
    null :
    try(
      coalesce(var.xrd_vr_cpuset, try(module.node_props[0].cpuset, null)),
      null,
    )
  )

  xrd_vr_cpuset_list = try(
    range(
      split("-", local.xrd_vr_cpuset)[0],
      split("-", local.xrd_vr_cpuset)[1] + 1,
    ),
    null,
  )

  xrd_vr_cp_num_cpus = (
    var.isolated_cores != null ?
    null :
    try(
      coalesce(var.xrd_vr_cp_num_cpus, try(module.node_props[0].cp_num_cpus, null)),
      null,
    )
  )

  isolated_cores_list = try(
    range(
      split("-", var.isolated_cores)[0],
      split("-", var.isolated_cores)[1] + 1,
    ),
    range(
      local.xrd_vr_cpuset_list[0] + local.xrd_vr_cp_num_cpus,
      split("-", local.xrd_vr_cpuset)[1] + 1,
    ),
    null,
  )

  isolated_cores = try(
    coalesce(
      var.isolated_cores,
      "${local.isolated_cores_list[0]}-${local.isolated_cores_list[length(local.isolated_cores_list) - 1]}",
    ),
    null,
  )

  # Add a 'name' label to the user-provided labels.
  # Note that this takes precedence (`merge` has right-precedence); this is
  # because the "wait" Job below is scheduled onto this node via this label.
  required_labels = {
    "ios-xr.cisco.com/name" = var.name
  }
  labels = var.labels != null ? merge(var.labels, local.required_labels) : local.required_labels

  kubelet_node_labels_arg = join(",", [for k, v in local.labels : "${k}=${v}"])
}

resource "aws_instance" "this" {
  lifecycle {
    precondition {
      condition     = !local.is_xrd_ami || local.hugepages_gb != null
      error_message = <<-EOT
      Hugepages was not provided and could not be calculated, and an AMI generated by XRd Packer is used.
      This means you are using an instance type for which an appropriate hugepages value is not known.
      Try using a different instance type, or set 'var.hugepages_gb' to an appropriate value.
      EOT
    }

    precondition {
      condition     = !local.is_xrd_ami || local.isolated_cores != null
      error_message = <<-EOT
      Isolated cores was not provided and could not be calculated, and an AMI generated by XRd Packer is used.
      This means you are using an instance type for which an appropriate isolated cores value is not known.
      Try using a different instance type, or set 'var.isolated_cores' or 'var.xrd_vr_cpuset' to an appropriate value.
      EOT
    }

    # Secondary IP addresses are assigned to the instance by the VPC CNI.
    ignore_changes = [secondary_private_ips]
  }

  ami                         = var.ami
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile
  instance_type               = var.instance_type
  key_name                    = var.key_name
  placement_group             = var.placement_group

  # Primary network interface.
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip_address
  secondary_private_ips  = var.secondary_private_ips
  vpc_security_group_ids = var.security_groups
  source_dest_check      = false

  # Turn off SMT.
  cpu_options {
    core_count       = data.aws_ec2_instance_type.this.default_cores
    threads_per_core = 1
  }

  # Set the user data with bootstrap info.
  user_data = templatefile(
    "${path.module}/templates/user-data.tftpl",
    {
      name = data.aws_eks_cluster.this.name
      api_endpoint = data.aws_eks_cluster.this.endpoint
      certificate_authority = data.aws_eks_cluster.this.certificate_authority[0].data
      cidr = data.aws_eks_cluster.this.vpc_config[0].public_access_cidrs[0]
    }
  )

  user_data_replace_on_change = true

  root_block_device {
    # Increase the root block device size to 56 GB for core handling.
    volume_size = 56
  }

  metadata_options {
    # A hop limit of at least 2 is required to access the endpoint
    # from inside a container (e.g. for the HA app).
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  tags = {
    Name                                        = var.name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_network_interface" "this" {
  for_each = {
    for i, ni in var.network_interfaces :
    i => ni
  }

  subnet_id         = each.value.subnet_id
  private_ips       = each.value.private_ips
  security_groups   = each.value.security_groups
  source_dest_check = false

  attachment {
    device_index = each.key + 1
    instance     = aws_instance.this.id
  }

  tags = {
    "node.k8s.amazonaws.com/no_manage" = "true"
  }
}

resource "time_sleep" "wait" {
  count = var.wait ? 1 : 0

  # Wait for 10 seconds before starting the node-readiness Job.
  # If using an XRd-compatible AMI this should give enough time for the XRd
  # bootstrap script to run.
  create_duration = "10s"

  triggers = {
    id = aws_instance.this.id
  }
}

resource "kubernetes_job" "wait" {
  count = var.wait ? 1 : 0

  metadata {
    generate_name = "wait-for-node-ready-"
    namespace     = "kube-system"
    labels = {
      "triggered-by" = replace(time_sleep.wait[0].id, ":", "-")
    }
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "main"
          image   = "alpine"
          command = ["sh", "-c", "true"]
        }

        node_selector = {
          "ios-xr.cisco.com/name" = aws_instance.this.tags["Name"]
        }

        restart_policy = "Never"
      }
    }
  }

  timeouts {
    # If using the XRd-compatible AMI we must wait for the XRd bootstrap
    # script, the EKS bootstrap script, and reboot.  This is a bit of a
    # guessing game but 10 minutes should be more than enough.
    create = "10m"
  }

  wait_for_completion = true
}
