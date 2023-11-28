# Singleton

The Singleton example brings up a single XRd Control Plane or XRd vRouter instance, with three line interfaces.

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
