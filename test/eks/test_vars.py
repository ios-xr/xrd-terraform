from typing import Any

import pytest

from ..utils import MotoServer, Terraform
from . import Cluster


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir, tf) -> None:
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def test_name(eks_client: ..., tf: Terraform, base_vars: dict[str, Any]):
    name = "my-custom-name"
    tf.apply(vars=base_vars | {"name": name})
    cluster = Cluster.from_name(eks_client, name)
    assert cluster.name == name


@pytest.mark.parametrize(
    "cluster_version", ("1.23", "1.24", "1.25", "1.26", "1.27")
)
def test_cluster_version(
    eks_client: ...,
    tf: Terraform,
    base_vars: dict[str, Any],
    cluster_version: str,
):
    tf.apply(vars=base_vars | {"cluster_version": cluster_version})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert cluster.version == cluster_version


def test_endpoint_public_access(
    eks_client: ..., tf: Terraform, base_vars: dict[str, Any]
):
    tf.apply(vars=base_vars | {"endpoint_public_access": False})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert not cluster.endpoint_public_access


def test_endpoint_private_access(
    eks_client: ..., tf: Terraform, base_vars: dict[str, Any]
):
    tf.apply(vars=base_vars | {"endpoint_private_access": False})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert not cluster.endpoint_private_access


def test_security_groups(
    eks_client: ..., tf: Terraform, base_vars: dict[str, Any], sg: ...
):
    tf.apply(vars=base_vars | {"security_group_ids": [sg.id]})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert len(cluster.security_group_ids) == 1
    assert sg.id in cluster.security_group_ids
