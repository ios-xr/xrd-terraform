import base64
import json
import uuid
from pathlib import Path
from typing import Any

import pytest
from attrs import define
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_ec2.service_resource import (
    Instance,
    KeyPair,
    SecurityGroup,
    Subnet,
    Vpc,
)
from mypy_boto3_iam import IAMServiceResource
from mypy_boto3_iam.service_resource import InstanceProfile

from terraform import Terraform, TerraformOutputs
from moto_server import MotoServer


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "node",
        f"http://localhost:{moto_server.port}",
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture
def vpc(ec2: EC2ServiceResource) -> Vpc:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture
def subnet(vpc: Vpc) -> Subnet:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a",
        CidrBlock="10.0.0.0/24",
    )


@pytest.fixture
def key_pair(ec2: EC2ServiceResource) -> KeyPair:
    return ec2.create_key_pair(KeyName=str(uuid.uuid4()))


@pytest.fixture
def iam_instance_profile(iam: IAMServiceResource) -> InstanceProfile:
    assume_role_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
            },
        ],
    }
    role_name = str(uuid.uuid4())
    role = iam.create_role(
        RoleName=role_name,
        AssumeRolePolicyDocument=json.dumps(assume_role_policy),
    )
    for policy_arn in (
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    ):
        role.attach_policy(PolicyArn=policy_arn)

    ret = iam.create_instance_profile(InstanceProfileName=str(uuid.uuid4()))
    ret.add_role(RoleName=role_name)
    return ret


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
def base_vars(
    subnet: Subnet,
    key_pair: KeyPair,
    iam_instance_profile: InstanceProfile,
) -> dict[str, Any]:
    # This AMI should exist in the Moto server.
    # Refer to https://github.com/getmoto/moto/blob/master/moto/ec2/resources/amis.json.
    ami = "ami-03cf127a"

    return {
        "ami": ami,
        "cluster_name": str(uuid.uuid4()),
        "name": str(uuid.uuid4()),
        "private_ip_address": "10.0.0.10",
        "subnet_id": subnet.id,
        "key_name": key_pair.key_name,
        "iam_instance_profile": iam_instance_profile.name,
    }


def _assert_tag(instance: Instance, tag_key: str, tag_value: str) -> None:
    """
    Assert an instance tag is as expected.

    :param tag_key:
        Expected tag key.

    :param tag_value:
        Expected tag value.

    :raises AssertionError:
        If the tag key does not exist, or the actual tag value does not match
        the expected tag value.

    """
    for tag in instance.tags:
        if tag["Key"] == tag_key:
            assert tag["Value"] == tag_value
            break
    else:
        raise AssertionError(f"tag '{tag_key}' does not exist")


def test_defaults(ec2, tf: Terraform, base_vars: dict[str, Any]):
    tf.apply(vars=base_vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    assert instance.key_name == base_vars["key_name"]
    assert instance.private_ip_address == base_vars["private_ip_address"]
    _assert_tag(
        instance,
        f"kubernetes.io/cluster/{base_vars['cluster_name']}",
        "owned",
    )
    _assert_tag(instance, "Name", base_vars["name"])

    # The default user data should call `bootstrap.sh` with the cluster name
    # as an argument.
    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert f"/etc/eks/bootstrap.sh {base_vars['cluster_name']}" in user_data

    # There should be no public IP address assigned.
    assert not instance.public_ip_address

    # Source/dest check should be disabled on the primary ENI.
    assert not instance.source_dest_check

    # There should be exactly one ENI attached - the primary ENI.
    assert len(instance.network_interfaces_attribute)
    assert (
        instance.network_interfaces_attribute[0]["PrivateIpAddress"]
        == base_vars["private_ip_address"]
    )
    assert not instance.network_interfaces_attribute[0]["SourceDestCheck"]
    assert (
        instance.network_interfaces_attribute[0]["SubnetId"]
        == base_vars["subnet_id"]
    )


def test_instance_type(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"instance_type": "m5n.24xlarge"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.instance_type == "m5n.24xlarge"


def test_kubelet_extra_args(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"kubelet_extra_args": "foo bar baz"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert (
        f"""--kubelet-extra-args '--node-labels=name={base_vars["name"]} foo bar baz'"""
        in user_data
    )


def test_security_groups(
    ec2,
    tf: Terraform,
    base_vars: dict[str, Any],
    security_group: SecurityGroup,
):
    vars = base_vars | {"security_groups": [security_group.id]}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    assert len(instance.network_interfaces_attribute) == 1
    assert len(instance.network_interfaces_attribute[0]["Groups"]) == 1
    assert (
        instance.network_interfaces_attribute[0]["Groups"][0]["GroupId"]
        == security_group.id
    )


def test_user_data(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"user_data": "this is my user data"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert "this is my user data" in user_data
