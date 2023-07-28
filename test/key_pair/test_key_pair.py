from dataclasses import dataclass
from ..utils import run_cmd
import subprocess
import uuid
from pathlib import Path

import boto3
import pytest
from botocore.exceptions import ClientError


@dataclass
class Terraform:
    working_dir: Path

    def init(self, *, upgrade: bool=False) -> subprocess.CompletedProcess[str]:
        cmd = ["terraform", f"-chdir={self.working_dir}", "init"]
        if upgrade:
            cmd.append("-upgrade")
        return run_cmd(cmd)

    def apply(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = ["terraform", f"-chdir={self.working_dir}", "apply", "-no-color"]
        if vars:
            for k, v in vars.items():
                cmd.append(f"-var={k}={v}")
        if auto_approve:
            cmd.append("-auto-approve")
        return run_cmd(cmd)

    def destroy(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = [
            "terraform",
            f"-chdir={self.working_dir}",
            "destroy",
            "-no-color",
        ]
        if vars:
            for k, v in vars.items():
                cmd.append(f"-var={k}={v}")
        if auto_approve:
            cmd.append("-auto-approve")
        return run_cmd(cmd)

    def output(self) -> subprocess.CompletedProcess:
        return run_cmd(
            ["terraform", f"-chdir={self.working_dir}", "output", "-json"]
        )


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def key_name() -> str:
    return str(uuid.uuid4())


@pytest.fixture(scope="module")
def filename(this_dir: Path, key_name: str) -> Path:
    return this_dir / f"{key_name}.pem"


@pytest.fixture
def tf(this_dir: Path) -> Terraform:
    tf = Terraform(this_dir)
    tf.init(upgrade=True)
    return tf


def test_key_pair_exists(tf: Terraform, key_name: str):
    tf.apply(vars={"key_name": key_name, "filename": filename})
    ec2 = boto3.resource("ec2", endpoint_url="http://localhost:5000")
    try:
        ec2.KeyPair(key_name).load()
    except ClientError:
        assert False


def test_key_pair_written(tf: Terraform, key_name: str, filename: Path):
    tf.apply(vars={"key_name": key_name, "filename": filename})
    assert filename.is_file()
