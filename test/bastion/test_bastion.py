from pathlib import Path

import boto3
import pytest
from attrs import define

from ..utils import Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    id: str
    public_ip: str
    key_pair_filename: str


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


def test_instance_exists(tf: Terraform):
    tf.apply(vars={"ami": "ami-dummy"})
    outputs = Outputs.from_terraform(tf)
    ec2 = boto3.resource("ec2")
    ec2.Instance(outputs.id).load()
