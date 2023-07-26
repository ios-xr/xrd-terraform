import json
import subprocess
from dataclasses import dataclass
from ipaddress import IPv4Address
from pathlib import Path

import boto3
import pytest

from ..utils import run_cmd, wait_until


@dataclass
class Outputs:
    id: str
    public_ip: IPv4Address

    @classmethod
    def from_jsons(cls, s: str):
        d = json.loads(s)
        return cls(d["id"]["value"], IPv4Address(d["public_ip"]["value"]))


@dataclass
class Terraform:
    working_dir: Path

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
def working_dir() -> Path:
    this_dir = Path(__file__).parent
    return this_dir.parent.parent / "modules" / "aws" / "bastion"


@pytest.fixture(scope="module", autouse=True)
def init(working_dir: Path) -> None:
    run_cmd(["terraform", "init", "-upgrade"])
    run_cmd(["terraform", "apply", "-auto-approve"])
    run_cmd(["terraform", f"-chdir={working_dir}", "init", "-upgrade"])


@pytest.fixture(scope="module")
def terraform_outputs(init: None) -> dict[str, str]:
    out = run_cmd(["terraform", "output", "-json"]).stdout
    return json.loads(out)


@pytest.fixture(scope="module")
def key_name(terraform_outputs: dict[str, str]) -> str:
    return terraform_outputs["key_name"]["value"]


@pytest.fixture(scope="module")
def key_pair_filename(terraform_outputs: dict[str, str]) -> Path:
    return Path(terraform_outputs["key_pair_filename"]["value"]).resolve()


@pytest.fixture(scope="module")
def tf(working_dir: Path):
    return Terraform(working_dir)


@pytest.fixture(scope="module")
def default_subnet_id() -> str:
    ec2 = boto3.client("ec2")
    return ec2.describe_subnets(
        Filters=[{"Name": "default-for-az", "Values": ["true"]}]
    )["Subnets"][0]["SubnetId"]


@pytest.fixture(scope="module", autouse=True)
def destroy(tf: Terraform, default_subnet_id: str, key_name: str) -> None:
    yield
    tf.destroy(vars={"subnet_id": default_subnet_id, "key_name": key_name})
    run_cmd(["terraform", "destroy", "-auto-approve"])


def test_key_pair_exists(key_pair_filename: Path):
    assert key_pair_filename.is_file()


def test_instance_exists(tf: Terraform, default_subnet_id: str, key_name: str):
    tf.apply(
        vars={"subnet_id": default_subnet_id, "key_name": key_name}
    ).stdout
    outputs = Outputs.from_jsons(tf.output().stdout)
    ec2 = boto3.resource("ec2")
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
    tf.apply(
        vars={"subnet_id": default_subnet_id, "key_name": key_name}
    ).stdout
    outputs = Outputs.from_jsons(tf.output().stdout)
    ec2 = boto3.resource("ec2")
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
