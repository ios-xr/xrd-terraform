# Overlay

This example brings up two XRd vRouter instances connected via an overlay network constructed using GRE, IS-IS and L3VPN, as well as two Alpine Linux containers that are connected to each other via the overlay network (i.e. through the two XRd routers).

## Usage

The [Bootstrap configuration](/examples/bootstrap/README.md) must be applied before running this example.

Then to run this example, execute:

```
terraform -chdir=infra init
terraform -chdir=infra apply
terraform -chdir=workload init
terraform -chdir=workload apply
```

To destroy this example, execute:

```
terraform -chdir=workload destroy
terraform -chdir=infra destroy
```

## Inputs

Configuration inputs are documented on the [infra configuration](infra/README.md) and [workload configuration](workload/README.md) pages.

## Outputs

Configuration outputs are documented on the [workload configuration](workload/README.md) page.
