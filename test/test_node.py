import base64
import json
import logging
import uuid
from pathlib import Path
from typing import Any

import pytest
from attrs import define

from ._types import MotoServer, Terraform, TerraformOutputs

logger = logging.getLogger(__name__)


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str


@pytest.fixture(autouse=True)
def vpc(ec2: ...) -> ...:
    vpcs = list(
        ec2.vpcs.filter(Filters=[{"Name": "cidr", "Values": ["10.0.0.0/16"]}])
    )
    if vpcs:
        return vpcs[0]
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(autouse=True)
def subnet(vpc: ...) -> ...:
    for subnet in vpc.subnets.all():
        if subnet.cidr_block == "10.0.0.0/24":
            return subnet
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.0.0/24"
    )


@pytest.fixture(autouse=True)
def key_pair(ec2: ...) -> ...:
    return ec2.create_key_pair(KeyName=str(uuid.uuid4()))


@pytest.fixture(autouse=True)
def iam_instance_profile(iam: ...) -> ...:
    assume_role_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
            }
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
def base_vars(
    subnet: ..., key_pair: ..., iam_instance_profile: ...
) -> dict[str, Any]:
    # This AMI should exist in the Moto server.
    # Refer to https://github.com/getmoto/moto/blob/master/moto/ec2/resources/amis.json.
    ami = "ami-03cf127a"

    return {
        "ami": ami,
        "cluster_name": str(uuid.uuid4()),
        "name": str(uuid.uuid4()),
        "network_interfaces": [],
        "private_ip_address": "10.0.0.10",
        "subnet_id": subnet.id,
        "key_name": key_pair.key_name,
        "iam_instance_profile": iam_instance_profile.name,
    }


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "node", f"http://localhost:{moto_server.port}"
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def _assert_tag(instance: ..., tag_key: str, tag_value: str) -> None:
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
        instance, f"kubernetes.io/cluster/{base_vars['cluster_name']}", "owned"
    )
    _assert_tag(instance, "Name", base_vars["name"])
    assert not instance.public_ip_address
    assert not instance.source_dest_check

    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert f"/etc/eks/bootstrap.sh {base_vars['cluster_name']}" in user_data


def test_instance_type(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"instance_type": "m5n.24xlarge"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.instance_type == "m5n.24xlarge"


def test_kubelet_extra_args(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"kubelet_extra_args": "cha cha cha"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert (
        f"""--kubelet-extra-args '--node-labels=name={base_vars["name"]} cha cha cha'"""
        in user_data
    )


def test_name(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"name": "a whole new name!"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    expected_tag_key = f"Name"
    for tag in instance.tags:
        if tag["Key"] == expected_tag_key:
            assert tag["Value"] == "a whole new name!"
            break
    else:
        assert False, f"tag '{expected_tag_key}' does not exist"


def test_private_ip_address(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"private_ip_address": "10.0.0.200"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.private_ip_address == "10.0.0.200"


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
