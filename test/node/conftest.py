from pathlib import Path
from typing import Any

import boto3
import pytest

from ..utils import MotoServer, Terraform


@pytest.fixture(scope="package")
def ec2() -> None:
    return boto3.resource("ec2")


@pytest.fixture(scope="package")
def ec2_client() -> None:
    return boto3.client("ec2")


@pytest.fixture(scope="package")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="package")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="package")
def base_vars() -> dict[str, Any]:
    return {
        "ami": "ami-03cf127a",
        "cluster_name": "test-cluster",
        "name": "foo",
        "network_interfaces": [],
        "private_ip_address": "10.0.0.10",
    }
