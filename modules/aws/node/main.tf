terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }
  }
}

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

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

data "aws_ami" "this" {
  filter {
    name   = "image-id"
    values = [var.ami]
  }
}

locals {
  instance_type_to_isolated_cores = {
    "m5.2xlarge" : "2-3",
    "m5n.2xlarge" : "2-3",
    "m5.24xlarge" : "16-23",
    "m5n.24xlarge" : "16-23",
  }

  instance_type_to_xrd_cpuset = {
    "m5.2xlarge" : "2-3",
    "m5n.2xlarge" : "2-3",
    "m5.24xlarge" : "12-23",
    "m5n.24xlarge" : "12-23",
  }

  instance_type_to_hugepages_gb = {
    "m5.2xlarge" : "6",
    "m5n.2xlarge" : "6",
    "m5.24xlarge" : "6",
    "m5n.24xlarge" : "6",
  }

  ami_generated_by_packer = [
    for k, v in data.aws_ami.this.tags : true
    if k == "Generated_By" && v == "xrd-packer"
  ]
  is_xrd_packer_ami = length(local.ami_generated_by_packer) > 0

  req_hugepages_gb = try(
    var.xrd_ami_data.hugepages_gb,
    local.instance_type_to_hugepages_gb[var.instance_type]
  )
  req_isolated_cores = try(
    var.xrd_ami_data.isolated_cores,
    local.instance_type_to_isolated_cores[var.instance_type]
  )

  hugepages_gb   = local.is_xrd_packer_ami ? local.req_hugepages_gb : null
  isolated_cores = local.is_xrd_packer_ami ? local.req_isolated_cores : null
}

resource "aws_instance" "this" {
  ami                  = var.ami
  iam_instance_profile = var.iam_instance_profile
  instance_type        = var.instance_type
  key_name             = var.key_name

  # Primary network interface.
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip_address
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
      xrd_bootstrap  = local.is_xrd_packer_ami
      hugepages_gb   = local.hugepages_gb
      isolated_cores = local.isolated_cores
      cluster_name   = var.cluster_name
      kubelet_extra_args = format(
        "--node-labels=name=%s %s",
        var.name,
        var.kubelet_extra_args
      )
      additional_user_data = var.user_data
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
  private_ips       = [each.value.private_ip_address]
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

resource "kubernetes_job" "wait" {
  metadata {
    generate_name = "wait-for-node-ready-"
    namespace     = "kube-system"
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
          name = aws_instance.this.tags["Name"]
        }
        restart_policy = "Never"
      }
    }
  }
  timeouts {
    create = "5m"
  }
  wait_for_completion = true
}
