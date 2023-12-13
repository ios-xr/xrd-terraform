# HA Example

The HA example brings up an EKS cluster with three nodes.

Two of the nodes are used for XRd vRouter instances, both with associated [HA apps](https://github.com/ios-xr/xrd-ha-app) running on the same node.

The third node is use to run three alpine containers, which are all on on separate subnets and can communicate to each other via the XRd instances.

The topology can be used to show both modes of operation for the example HA application.

## How to run

See [Running Examples](/README.md#running-examples).
