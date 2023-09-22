import base64
import logging
from pathlib import Path
from typing import Any

import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs

logger = logging.getLogger(__name__)


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)
    (this_dir / "test-cluster-instance.pem").unlink(missing_ok=True)


def test_ami(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"ami": "ami-12c6146b"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.image_id == "ami-12c6146b"


def test_cluster_name(ec2, tf: Terraform, base_vars: dict[str, Any]):
    cluster_name = "foo"

    vars = base_vars | {"cluster_name": cluster_name}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    expected_tag_key = f"kubernetes.io/cluster/{cluster_name}"
    for tag in instance.tags:
        if tag["Key"] == expected_tag_key:
            assert tag["Value"] == "owned"
            break
    else:
        assert False, f"tag '{expected_tag_key}' does not exist"

    user_data = instance.describe_attribute(Attribute="userData")["UserData"][
        "Value"
    ]
    user_data = base64.b64decode(user_data).decode()
    assert f"/etc/eks/bootstrap.sh {cluster_name}" in user_data


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


def test_instance_type(ec2, tf: Terraform, base_vars: dict[str, Any]):
    vars = base_vars | {"instance_type": "m5n.24xlarge"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.instance_type == "m5n.24xlarge"


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
    vars = base_vars | {"private_ip_address": "10.0.100.10"}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)
    assert instance.private_ip_address == "10.0.100.10"


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
