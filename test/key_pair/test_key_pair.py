import os
from pathlib import Path
from typing import Any

import botocore.exceptions
import pytest

from ..utils import MotoServer, Terraform


@pytest.fixture(scope="module", autouse=True)
def apply(tf: Terraform, base_vars: dict[str, Any]) -> None:
    tf.apply(vars=base_vars)


@pytest.fixture(scope="module", autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def test_key_pair_exists(ec2, base_vars: dict[str, Any]):
    try:
        ec2.KeyPair(base_vars["key_name"]).load()
    except botocore.exceptions.ClientError as exc:
        raise AssertionError from exc


def test_key_pair_written(base_vars: dict[str, Any]):
    assert os.path.exists(base_vars["filename"])
