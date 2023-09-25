from pathlib import Path
from typing import Any

import pytest

from ..utils import Terraform


@pytest.fixture(scope="package")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="package")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="package", autouse=True)
def vpc(ec2) -> None:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(scope="package", autouse=True)
def subnet(vpc) -> None:
    return vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.10.0/24"
    )


@pytest.fixture(scope="package", autouse=True)
def key_pair(ec2) -> ...:
    return ec2.create_key_pair(KeyName="test-key-pair")


@pytest.fixture(scope="package")
def base_vars(subnet, key_pair) -> dict[str, Any]:
    return {
        "ami": "ami-dummy",
        "key_name": key_pair.key_name,
        "subnet_id": subnet.id,
    }
