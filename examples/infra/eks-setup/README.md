# EKS Setup

This configuration sets up an existing EKS cluster so that it is suitable
for running XRd workloads:

- [IAM principal access](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
  is enabled.
- The [`MAX_ENI` VPC CNI configuration variable](https://github.com/aws/amazon-vpc-cni-k8s#max_eni)
  is set to 1.
- The [EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
  is installed.
- [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) is installed.

In addition, a simple Bastion host is launched in the public subnet for
access.

## How to run

See [Running Examples](/README.md#running-examples).
