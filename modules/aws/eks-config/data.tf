data "aws_iam_policy" "ebs_csi_driver_policy" {
  name = "AmazonEBSCSIDriverPolicy"
}

data "aws_region" "current" {}

data "http" "multus_yaml" {
  url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/multus/v3.7.2-eksbuild.1/aws-k8s-multus.yaml"
}
