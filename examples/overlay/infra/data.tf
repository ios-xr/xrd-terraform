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

data "aws_subnet" "cluster" {
  id = local.bootstrap.private_subnet_ids[0]
}
