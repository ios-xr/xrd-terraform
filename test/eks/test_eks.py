from pathlib import Path

import boto3
import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    subnet_one_id: str
    subnet_two_id: str


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir, tf) -> None:
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture(autouse=True)
def vpc(ec2) -> None:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(autouse=True)
def subnets(vpc) -> None:
    s1 = vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.10.0/24"
    )
    s2 = vpc.create_subnet(
        AvailabilityZone="eu-west-1b", CidrBlock="10.0.11.0/24"
    )
    return s1, s2


@pytest.fixture
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


def check_cluster(
    *,
    name: str,
    cluster_version: str,
    endpoint_public_access: bool = True,
    endpoint_private_access: bool = True,
    security_group_ids: list[str] | None = None,
):
    eks = boto3.client("eks")
    resp = eks.describe_cluster(name=name)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200
    cluster = resp["cluster"]
    assert cluster["name"] == name
    assert cluster["version"] == cluster_version
    assert (
        cluster["resourcesVpcConfig"]["endpointPublicAccess"]
        == endpoint_public_access
    )
    assert (
        cluster["resourcesVpcConfig"]["endpointPrivateAccess"]
        == endpoint_private_access
    )
    if security_group_ids:
        assert set(cluster["resourcesVpcConfig"]["securityGroupIds"]) == set(
            security_group_ids
        )
    else:
        assert len(cluster["resourcesVpcConfig"]["securityGroupIds"]) == 0


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
