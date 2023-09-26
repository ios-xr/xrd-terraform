import uuid
from pathlib import Path
from typing import Any

import boto3
import pytest

from ..utils import MotoServer, Terraform
from . import Cluster


@pytest.fixture(scope="module")
def eks_client(moto_server: MotoServer) -> ...:
    return boto3.client("eks", endpoint_url=moto_server.endpoint)


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module", autouse=True)
def vpc(ec2) -> ...:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(scope="module", autouse=True)
def subnets(vpc) -> None:
    s1 = vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.10.0/24"
    )
    s2 = vpc.create_subnet(
        AvailabilityZone="eu-west-1b", CidrBlock="10.0.11.0/24"
    )
    return s1, s2


@pytest.fixture(scope="module", autouse=True)
def sg(ec2, vpc) -> None:
    sg = ec2.create_security_group(
        GroupName="ssh", Description="ssh", VpcId=vpc.vpc_id
    )
    sg.authorize_ingress(
        IpProtocol="tcp",
        FromPort=22,
        ToPort=22,
        CidrIp="0.0.0.0/0",
    )
    return sg


@pytest.fixture(scope="module")
def base_vars(subnets):
    return {
        "cluster_version": "1.27",
        "name": str(uuid.uuid4()),
        "subnet_ids": [subnets[0].id, subnets[1].id],
    }


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir, tf) -> None:
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def test_defaults(eks_client: ..., base_vars: dict[str, Any], tf: Terraform):
    tf.apply(vars=base_vars)
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert cluster
    assert cluster.version == base_vars["cluster_version"]
    assert cluster.endpoint_private_access
    assert cluster.endpoint_public_access
    assert len(cluster.security_group_ids) == 0


def test_name(eks_client: ..., tf: Terraform, base_vars: dict[str, Any]):
    name = str(uuid.uuid4())
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
