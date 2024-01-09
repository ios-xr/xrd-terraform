# HA

This example demonstrates the use of XRd vRouter as a redundant Cloud Router.

Two Alpine Linux containers are connected to each other via a redundant pair of XRd vRouter instances.

## Usage

The [Bootstrap configuration](/examples/bootstrap/README.md) must be applied before running this example.

Then to run this example, execute:

```
terraform -chdir=infra init
terraform -chdir=infra apply
terraform -chdir=workload init
terraform -chdir=workload apply
```

This should take around two minutes to complete.  You may then configure `kubectl` so that you can connect to the cluster:

```
aws eks update-kubeconfig --name $(terraform -chdir=workload output -raw cluster_name)
```

Traffic from the CNF to the Peer container is routed via the active XRd vRouter instance.  To simulate failure of the active XRd vRouter instance:

```sh
# Ping from the CNF to the Peer should succeed after initialization:
kubectl exec deploy/cnf-vrid1 -- ping -c5 10.0.10.12
kubectl exec deploy/cnf-vrid2 -- ping -c5 10.0.10.12

# Simulate a failure of the active XRd vRouter instance:
kubectl rollout restart sts/xrd1

# Traffic is restored after up to ~30 seconds:
kubectl exec deploy/cnf-vrid1 -- ping 10.0.10.12
kubectl exec deploy/cnf-vrid2 -- ping -c5 10.0.10.12
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

## Troubleshooting

It is possible to use a local copy of the HA app Helm chart when applying the workload configuration, by providing a local path for the workload configuration variable `ha_app_chart_name`, and `null` for the workload configuration variable `ha_app_chart_repository`.

All on-disk dependencies of the local Helm chart must be present.  If not, then you may see the following `terraform apply` error:

```
│ Error: found in Chart.yaml, but missing in charts/ directory: xrd-vrouter
│
│   with helm_release.xrd1,
│   on main.tf line 42, in resource "helm_release" "xrd1":
│   42: resource "helm_release" "xrd1" {
```

The fix is to run [`helm dependency update`](https://helm.sh/docs/helm/helm_dependency_update/).
