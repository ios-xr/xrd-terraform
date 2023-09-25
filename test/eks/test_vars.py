from pathlib import Path

import boto3
import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs
from . import Outputs


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir, tf) -> None:
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def check_cluster(
    *,
    name: str,
    cluster_version: str,
    endpoint_public_access: bool = True,
    endpoint_private_access: bool = True,
    security_group_ids: list[str] | None = None,
):
    eks = boto3.client("eks")


def test_default(tf: Terraform, subnets):
    tf.apply(
        vars={
            "name": "foo",
            "cluster_version": "1.27",
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(name="foo", cluster_version="1.27")


def test_set_name(tf: Terraform, subnets):
    tf.apply(
        vars={
            "name": "my-custom-name",
            "cluster_version": "1.27",
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(name="my-custom-name", cluster_version="1.27")


@pytest.mark.parametrize(
    "cluster_version", ("1.23", "1.24", "1.25", "1.26", "1.27")
)
def test_set_cluster_version(tf: Terraform, subnets, cluster_version: str):
    tf.apply(
        vars={
            "name": "foo",
            "cluster_version": cluster_version,
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(
        name="foo",
        cluster_version=cluster_version,
    )


def test_set_endpoint_public_access(tf: Terraform, subnets):
    tf.apply(
        vars={
            "name": "foo",
            "cluster_version": "1.27",
            "endpoint_public_access": True,
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(
        name="foo", cluster_version="1.27", endpoint_public_access=True
    )


def test_set_endpoint_private_access(tf: Terraform, subnets):
    tf.apply(
        vars={
            "name": "foo",
            "cluster_version": "1.27",
            "endpoint_private_access": True,
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(
        name="foo", cluster_version="1.27", endpoint_private_access=True
    )


def test_set_sg(tf: Terraform, subnets, sg):
    tf.apply(
        vars={
            "name": "foo",
            "cluster_version": "1.27",
            "security_group_ids": [sg.id],
            "subnet_ids": [subnets[0].id, subnets[1].id],
        }
    )
    check_cluster(
        name="foo",
        cluster_version="1.27",
        security_group_ids=[sg.id],
    )
