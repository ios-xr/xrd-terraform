import json
import subprocess
from dataclasses import dataclass
from ipaddress import IPv4Address
from pathlib import Path

import boto3
import pytest

from ..utils import Terraform, run_cmd, wait_until


@dataclass
class Outputs:
    id: str
    public_ip: IPv4Address

    @classmethod
    def from_jsons(cls, s: str):
        d = json.loads(s)
        return cls(d["id"]["value"], IPv4Address(d["public_ip"]["value"]))


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path) -> Terraform:
    tf = Terraform(this_dir)
    tf.init(upgrade=True)
    return tf


def test_instance_exists(tf: Terraform):
    tf.apply()
    outputs = Outputs.from_jsons(tf.output(out).stdout)
    ec2 = boto3.resource("ec2", endpoint_url="http://localhost:5000")
    ec2.Instance(outputs.id).load()


def check_run_cmd(*args, **kwargs) -> bool:
    try:
        run_cmd(*args, **kwargs)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return False
    else:
        return True


def test_ssh(
    tf: Terraform,
    default_subnet_id: str,
    key_name: str,
    key_pair_filename: Path,
):
    tf.apply()
    outputs = Outputs.from_jsons(tf.output(out).stdout)
    ec2 = boto3.resource("ec2", endpoint_url="http://localhost:5000")
    assert wait_until(
        120,
        10,
        check_run_cmd,
        [
            "ssh",
            "-i",
            str(key_pair_filename),
            f"ec2-user@{outputs.public_ip}",
            "true",
        ],
    )
