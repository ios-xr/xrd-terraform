import json
from ..utils import run_cmd
import subprocess
import uuid
from pathlib import Path

import boto3
import pytest


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
def terraform_outputs(init: None) -> dict[str,str]:
    out = run_cmd(["terraform", "output", "-json"]).stdout
    return json.loads(out)


@pytest.fixture(scope="module")
def key_name(terraform_outputs: dict[str,str]) -> str:
    return terraform_outputs["key_name"]["value"]


@pytest.fixture(scope="module")
def key_pair_filename(terraform_outputs: dict[str,str]) -> Path:
    return Path(terraform_outputs["key_pair_filename"]["value"]).resolve()


@pytest.fixture(scope="module", autouse=True)
def destroy(working_dir: Path, key_name: str) -> None:
    yield
    run_cmd(["terraform", f"-chdir={working_dir}", "destroy", "-auto-approve", f"-var=key_name={key_name}", "-var=subnet_id=foo"])
    run_cmd(["terraform", "destroy", "-auto-approve"])


def test_key_pair_exists(key_pair_filename: Path):
    assert key_pair_filename.is_file()
