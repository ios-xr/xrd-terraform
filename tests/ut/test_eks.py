import uuid
from pathlib import Path
from typing import Any

import botocore.errorfactory
import pytest
from attrs import define
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_ec2.service_resource import SecurityGroup, Subnet, Vpc
from mypy_boto3_eks import EKSClient

from terraform import Terraform

from .moto_server import MotoServer


@define
class Cluster:
    """Represents an EKS cluster resource."""

    name: str
    version: str
    endpoint_public_access: bool
    endpoint_private_access: bool
    security_group_ids: set[str]

    @classmethod
    def from_name(cls, eks_client: EKSClient, name: str):
        try:
            resp = eks_client.describe_cluster(name=name)
        except botocore.errorfactory.ResourceNotFoundException:
            return None

        if resp["ResponseMetadata"]["HTTPStatusCode"] != 200:
            return None

        cluster = resp["cluster"]

        return cls(
            name,
            cluster["version"],
            cluster["resourcesVpcConfig"]["endpointPublicAccess"],
            cluster["resourcesVpcConfig"]["endpointPrivateAccess"],
            set(cluster["resourcesVpcConfig"]["securityGroupIds"]),
        )


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "eks",
        vars={"aws_endpoint": f"http://localhost:{moto_server.port}"},
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir, tf) -> None:
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture
def vpc(ec2) -> Vpc:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture
def subnet1(vpc: Vpc) -> Subnet:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a",
        CidrBlock="10.0.10.0/24",
    )


@pytest.fixture
def subnet2(vpc: Vpc) -> Subnet:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a",
        CidrBlock="10.0.11.0/24",
    )


@pytest.fixture
def security_group(ec2: EC2ServiceResource, vpc: Vpc) -> SecurityGroup:
    sg = ec2.create_security_group(
        GroupName="ssh",
        Description="ssh",
        VpcId=vpc.vpc_id,
    )
    sg.authorize_ingress(
        IpProtocol="tcp",
        FromPort=22,
        ToPort=22,
        CidrIp="0.0.0.0/0",
    )
    return sg


@pytest.fixture
def base_vars(subnet1: Subnet, subnet2: Subnet) -> dict[str, Any]:
    return {
        "cluster_version": "1.32",
        "name": str(uuid.uuid4()),
        "subnet_ids": [subnet1.id, subnet2.id],
    }


def test_defaults(
    eks_client: EKSClient,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    tf.apply(vars=base_vars)
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert cluster
    assert cluster.endpoint_private_access
    assert cluster.endpoint_public_access
    assert len(cluster.security_group_ids) == 0
    assert cluster.version == base_vars["cluster_version"]


@pytest.mark.parametrize(
    "cluster_version",
    (
        "1.24",
        "1.25",
        "1.26",
        "1.27",
        "1.28",
        "1.29",
        "1.30",
    ),
)
def test_cluster_version(
    eks_client: EKSClient,
    tf: Terraform,
    base_vars: dict[str, Any],
    cluster_version: str,
):
    tf.apply(vars=base_vars | {"cluster_version": cluster_version})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert cluster.version == cluster_version


def test_endpoint_private_access(
    eks_client: EKSClient,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    tf.apply(vars=base_vars | {"endpoint_private_access": False})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert not cluster.endpoint_private_access


def test_endpoint_public_access(
    eks_client: EKSClient,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    tf.apply(vars=base_vars | {"endpoint_public_access": False})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert not cluster.endpoint_public_access


def test_security_groups(
    eks_client: EKSClient,
    tf: Terraform,
    base_vars: dict[str, Any],
    security_group: SecurityGroup,
):
    tf.apply(vars=base_vars | {"security_group_ids": [security_group.id]})
    cluster = Cluster.from_name(eks_client, base_vars["name"])
    assert len(cluster.security_group_ids) == 1
    assert security_group.id in cluster.security_group_ids
