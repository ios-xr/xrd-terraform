import uuid
from pathlib import Path
from typing import Any

import botocore.exceptions
import pytest
from attrs import define
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_ec2.service_resource import KeyPair, SecurityGroup, Subnet, Vpc

from terraform import Terraform, TerraformOutputs

from .moto_server import MotoServer


@define
class Outputs(TerraformOutputs):
    id: str
    public_ip: str


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "bastion",
        vars={"endpoint": f"http://localhost:{moto_server.port}"},
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture
def vpc(ec2) -> Vpc:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture
def subnet(vpc: Vpc) -> Subnet:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a",
        CidrBlock="10.0.10.0/24",
    )


@pytest.fixture
def key_pair(ec2: EC2ServiceResource) -> KeyPair:
    return ec2.create_key_pair(KeyName=str(uuid.uuid4()))


@pytest.fixture
def security_group(ec2: EC2ServiceResource, vpc: Vpc) -> SecurityGroup:
    return ec2.create_security_group(
        GroupName="dummy",
        Description="dummy",
        VpcId=vpc.vpc_id,
    )


@pytest.fixture
def base_vars(subnet: Subnet, key_pair: KeyPair) -> dict[str, Any]:
    # This AMI should exist in the Moto server.
    # Refer to https://github.com/getmoto/moto/blob/master/moto/ec2/resources/amis.json.
    ami = "ami-12c6146b"

    return {
        "ami": ami,
        "key_name": key_pair.key_name,
        "name": str(uuid.uuid4()),
        "subnet_id": subnet.id,
    }


def _assert_sgrs(sg: SecurityGroup, remote_access_cidr: list[str]) -> None:
    """Assert the 'bastion' security group has the expected ingress rules."""
    assert len(sg.ip_permissions) == 2

    icmp_sgr_found = False
    ssh_sgr_found = False
    for sgr in sg.ip_permissions:
        assert {x["CidrIp"] for x in sgr["IpRanges"]} == set(
            remote_access_cidr,
        )

        if sgr["IpProtocol"] == "icmp":
            assert not icmp_sgr_found
            icmp_sgr_found = True
            assert sgr["FromPort"] == -1
            assert sgr["ToPort"] == -1

        elif sgr["IpProtocol"] == "tcp":
            assert not ssh_sgr_found
            ssh_sgr_found = True
            assert sgr["FromPort"] == 22
            assert sgr["ToPort"] == 22

        else:
            raise AssertionError(f"unexpected protocol '{sgr['IpProtocol']}'")


def test_defaults(
    ec2: EC2ServiceResource,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    tf.apply(vars=base_vars)
    outputs = Outputs.from_terraform(tf)

    instance = ec2.Instance(outputs.id)

    # Assert the instance exists.
    try:
        instance.load()
    except botocore.exceptions.ClientError as exc:
        raise AssertionError from exc

    assert instance.image_id == base_vars["ami"]
    assert instance.instance_type == "t3.nano"
    assert instance.key_name == base_vars["key_name"]
    assert instance.public_ip_address == outputs.public_ip
    assert instance.subnet_id == base_vars["subnet_id"]

    assert len(instance.security_groups) == 1
    sg = ec2.SecurityGroup(instance.security_groups[0]["GroupId"])
    _assert_sgrs(sg, ["0.0.0.0/0"])


def test_instance_type(
    ec2: EC2ServiceResource,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    tf.apply(vars=base_vars | {"instance_type": "m5n.24xlarge"})
    outputs = Outputs.from_terraform(tf)

    instance = ec2.Instance(outputs.id)
    assert instance.instance_type == "m5n.24xlarge"


def test_security_groups(
    ec2: EC2ServiceResource,
    tf: Terraform,
    base_vars: dict[str, Any],
    security_group: SecurityGroup,
):
    tf.apply(vars=base_vars | {"security_group_ids": [security_group.id]})
    outputs = Outputs.from_terraform(tf)

    instance = ec2.Instance(outputs.id)
    assert len(instance.security_groups) == 2
    assert security_group.id in {
        x["GroupId"] for x in instance.security_groups
    }


def test_remote_access_cidr(
    ec2: EC2ServiceResource,
    tf: Terraform,
    base_vars: dict[str, Any],
):
    remote_access_cidr = ["192.168.0.0/24", "172.16.0.0/24"]
    tf.apply(vars=base_vars | {"remote_access_cidr": remote_access_cidr})
    outputs = Outputs.from_terraform(tf)

    instance = ec2.Instance(outputs.id)
    assert len(instance.security_groups) == 1
    sg = ec2.SecurityGroup(instance.security_groups[0]["GroupId"])
    _assert_sgrs(sg, remote_access_cidr)
