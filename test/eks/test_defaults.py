from pathlib import Path
from typing import Any

import pytest

from ..utils import MotoServer, Terraform
from . import Cluster


@pytest.fixture(scope="module", autouse=True)
def apply(tf: Terraform, base_vars: dict[str, Any]) -> None:
    tf.apply(vars=base_vars)


@pytest.fixture(scope="module", autouse=True)
def reset(moto_server: MotoServer, this_dir: Path, tf: Terraform) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture(scope="module")
def cluster(
    eks_client: ..., tf: Terraform, base_vars: dict[str, Any]
) -> Cluster:
    return Cluster.from_name(eks_client, base_vars["name"])


def test_cluster_exists(cluster: Cluster):
    assert cluster


def test_version(base_vars: dict[str, Any], cluster: Cluster):
    assert cluster.version == base_vars["cluster_version"]


def test_endpoint_public_access(cluster: Cluster):
    assert cluster.endpoint_public_access


def test_endpoint_private_access(cluster: Cluster):
    assert cluster.endpoint_public_access


def test_security_groups(cluster: Cluster):
    assert len(cluster.security_group_ids) == 0
