data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${data.aws_eks_cluster.this.version}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_eks_cluster" "this" {
  name = local.bootstrap.cluster_name
}

data "aws_iam_role" "node" {
  name = local.bootstrap.node_iam_role_name
}

data "aws_iam_policy_document" "ha_app" {
  # Allow describing (read-only) all EC2 instances and network interfaces.
  statement {
    actions   = ["ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces", "ec2:DescribeRouteTables"]
    resources = ["*"]
  }

  # Allow route modification on only the access route table created above.
  statement {
    actions = ["ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute"]
    resources = [format(
      "arn:aws:ec2:%s:%s:route-table/%s",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
      aws_route_table.cnf_vrid2.id,
    )]
  }

  # Allow IP [un]assignment on all network interfaces owned by the account
  # in the current region.
  statement {
    actions = ["ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"]
    resources = [format(
      "arn:aws:ec2:%s:%s:network-interface/*",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
    )]
  }
}

data "aws_subnet" "cluster" {
  id = local.bootstrap.private_subnet_ids[0]
}

data "aws_vpc" "this" {
  id = local.bootstrap.vpc_id
}
