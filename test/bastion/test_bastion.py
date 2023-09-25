from pathlib import Path
from typing import Any
import botocore.exceptions

import boto3
import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    id: str
    public_ip: str


@pytest.fixture(scope="module", autouse=True)
def apply(tf: Terraform, base_vars: dict[str, Any]) -> None:
    tf.apply(vars=base_vars)


@pytest.fixture(scope="module", autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture(scope="module")
def instance(ec2, tf: Terraform):
    outputs = Outputs.from_terraform(tf)
    return ec2.Instance(outputs.id)


def test_instance_exists(instance):
    try:
        instance.load()
    except botocore.exceptions.ClientError as exc:
        raise AssertionError from exc


def test_ami(base_vars, instance):
    assert instance.image_id == base_vars["ami"]


def test_instance_type(base_vars, instance):
    assert instance.instance_type == "t3.nano"


def test_key_name(base_vars, instance):
    assert instance.key_name == base_vars["key_name"]


def test_public_ip_address(tf, instance):
    outputs = Outputs.from_terraform(tf)
    assert instance.public_ip_address == outputs.public_ip


def test_security_groups(instance):
    assert len(instance.security_groups) == 1


def test_subnet_id(base_vars, instance):
    assert instance.subnet_id == base_vars["subnet_id"]
