# Overlay Example

The overlay example launches three nodes in an existing EKS cluster.

Two of the nodes are used for XRd vRouter instances, which are connected
back-to-back and have a GRE overlay running on the link.

The third node is used to host two alpine linux containers simulating
clients that can communicate with each other over the GRE link.

## How to run

See [Running Examples](/README.md#running-examples).
