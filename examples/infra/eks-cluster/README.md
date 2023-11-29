# EKS Cluster

This configuration creates a VPC and an EKS cluster.

The VPC is similar to the "Public and private subnets" VPC described
[here](https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html);
one public subnet and one private subnet in one Availability Zone, and an
additional private subnet in a different Availability Zone.

The EKS cluster is created in the two private subnets.

## How to run

See [Running Examples](/README.md#running-examples).
