import uuid
from pathlib import Path
from typing import Any

import botocore.exceptions
import pytest
from attrs import define

from ._types import MotoServer, Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    id: str
    public_ip: str


@pytest.fixture(scope="module", autouse=True)
def vpc(ec2) -> None:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(scope="module", autouse=True)
def subnet(vpc) -> None:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.10.0/24"
    )


@pytest.fixture(scope="module", autouse=True)
def key_pair(ec2) -> ...:
    return ec2.create_key_pair(KeyName=str(uuid.uuid4()))


@pytest.fixture(scope="module")
def base_vars(subnet, key_pair) -> dict[str, Any]:
    # This AMI should exist in the Moto server.
    # Refer to https://github.com/getmoto/moto/blob/master/moto/ec2/resources/amis.json.
    ami = "ami-12c6146b"

    return {
        "ami": ami,
        "key_name": key_pair.key_name,
        "subnet_id": subnet.id,
    }


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "bastion",
        f"http://localhost:{moto_server.port}",
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="module", autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def test_defaults(ec2: ..., base_vars: dict[str, Any], tf: Terraform):
    tf.apply(vars=base_vars)
    outputs = Outputs.from_terraform(tf)
    instance = ec2.Instance(outputs.id)

    try:
        instance.load()
    except botocore.exceptions.ClientError as exc:
        raise AssertionError from exc

    assert instance.image_id == base_vars["ami"]
    assert instance.instance_type == "t3.nano"
    assert instance.key_name == base_vars["key_name"]
    assert instance.public_ip_address == outputs.public_ip
    assert len(instance.security_groups) == 1
    assert instance.subnet_id == base_vars["subnet_id"]
