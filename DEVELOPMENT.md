# Development

This page is aimed at developers and testers, to help bring up custom
deployments for use in the lab. This page is not aimed at production users.

Before continuing, make sure you've read the [README](README.md).

## Recommended Workflows

The recommended workflow for development is to create your own Terraform
module using the resources in this repository to help bring up your
topology in AWS.

There are two recommended flows for this:
  1. Take a copy of an example and tweak it as your required.
  2. Use the flexible topology module (in `dev/flex`) to generate
     generic fully-connected infrastructure and edit the wrapper Helm
     chart it generates for your use-case.

### Copying an example

To do this, copy the entire example folder to a new folder, e.g. to start
from the overlay example run:

```
cp -r examples/overlay mymodule
cd mymodule
terraform init
terraform apply
```

Then make any changes you want an re-run `terraform apply` - Terraform
will calculate the required minimal changeset and apply it.

### Using the flexible topology module

The flexible topology module in `dev/flex` brings up a generic fully-connected
topology and creates a wrapper Helm chart that will bring up XRd instances
with basic username/password and interface/ip address configuration. The
chart allows you to specify the number of nodes and number of
interfaces on each node.

The IP addressing scheme is fixed. If there are M nodes each with N
interfaces, the IP addresses are as follows:
  - The primary interfaces on each EC2 node (used for the cluster control
    plane and not managed by XRd) range from 10.0.101.10 to to 10.0.101.(10+M-1)
  - The N additional interfaces on each worker node (used by XRd) range
    from 10.0.1.10 to 10.0.N.(10+M-1)
All the interfaces are in /24 subnets.

For example, if two worker nodes are created, each with three interfaces:

  - The first worker node's primary IP is 10.0.101.10, and it has
    additional interfaces with IPs 10.0.1.10, 10.0.2.10 and 10.0.3.10.
  - The second worker node's primary IP is 10.0.101.11, and it has
    additional interfaces with IPs 10.0.1.11, 10.0.2.11 and 10.0.3.11.

To create your own module that uses the flexible topology module, create
a new folder `mymodule` and a `main.tf` file inside it with the following
contents:

```
module "flex" {
  source = "git@wwwin-github.cisco.com:xrd/xrd-terraform.git//dev/flex"
  node_count = <number of required nodes>
  interface_count = <number of interfaces on each node>
}
```

The full set of configuration can be found by looking in the `variables.tf`
file inside the `dev/flex` module.

This can then be instantiated by the normal `terraform init` and
`terraform apply` flow.

## Cost Control

By far the largest cost of any setup is the EC2 instances.

Therefore, when a deployment is not in direct use, but is useful to keep
available, all the worker nodes in the cluster should be stopped. There
are two ways to do this:

  1. Terminate all the worker nodes when the cluster is not required.
     All of the example and developer modules in this repository support
     setting `create_nodes=false` to achieve this. If you've written
     your own module which does not support this, it can be achieved by
     setting the `count` meta-argument in all calls out to the `node` module
     to zero in your main Terraform module. Once this is done, re-run
     `terraform apply` to implement the changes.  When the cluster is required
     again, simply revert whatever change was made and run `terraform apply`
     once more.

  2. Stop all the worker nodes when the cluster is not required. This requires
     manual action in the AWS console or CLI to stop each worker node
     individually. In this state you are still charged for any
     allocated storage, but that is a trivial cost compared to the compute
     costs which are not charged when the instance is stopped.  When the
     cluster is required again the worker nodes can be started and the cluster
     will resume.
