import uuid
from pathlib import Path

import boto3
import pytest
from botocore.exceptions import ClientError

from ..utils import Terraform


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="module")
def key_name() -> str:
    return str(uuid.uuid4())


@pytest.fixture(scope="module")
def filename(this_dir: Path, key_name: str) -> Path:
    return this_dir / f"{key_name}.pem"


def test_key_pair_exists(tf: Terraform, key_name: str):
    tf.apply(vars={"key_name": key_name, "filename": str(filename)})
    ec2 = boto3.resource("ec2")
    try:
        ec2.KeyPair(key_name).load()
    except ClientError as exc:
        raise AssertionError from exc


def test_key_pair_written(tf: Terraform, key_name: str, filename: Path):
    tf.apply(vars={"key_name": key_name, "filename": str(filename)})
    assert filename.is_file()
