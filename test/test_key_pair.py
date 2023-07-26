import subprocess
import uuid
from pathlib import Path

import boto3
import pytest
from botocore.exceptions import ClientError


@pytest.fixture(scope="module")
def chdir() -> Path:
    this_dir = Path(__file__).parent
    return this_dir.parent / "modules" / "aws" / "key-pair"


@pytest.fixture(scope="module")
def key_name() -> str:
    return str(uuid.uuid4())


@pytest.fixture(scope="module")
def filename(key_name: str) -> Path:
    return Path(f"{key_name}.pem").resolve()


@pytest.fixture(scope="module", autouse=True)
def apply(chdir: Path, key_name: str, filename: str):
    try:
        subprocess.run(["terraform", f"-chdir={chdir}", "init", "-upgrade"])
        subprocess.run(
            [
                "terraform",
                f"-chdir={chdir}",
                "apply",
                "-auto-approve",
                f"-var=key_name={key_name}",
                f"-var=filename={filename}",
            ]
        )
        yield
    finally:
        subprocess.run(
            [
                "terraform",
                f"-chdir={chdir}",
                "destroy",
                "-auto-approve",
                f"-var=key_name={key_name}",
                f"-var=filename={filename}",
            ]
        )


def test_key_pair_exists(key_name: str):
    ec2 = boto3.resource("ec2")
    try:
        ec2.KeyPair(key_name).load()
    except ClientError:
        assert False


def test_key_pair_written(filename: Path):
    assert filename.is_file()
