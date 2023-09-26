import os
import uuid
from pathlib import Path
from typing import Any

import botocore.exceptions
import pytest

from .utils import MotoServer, Terraform


@pytest.fixture(scope="module")
def base_vars(this_dir: Path) -> dict[str, Any]:
    key_name = str(uuid.uuid4())
    return {
        "key_name": key_name,
        "filename": str(this_dir / f"{key_name}.pem"),
    }


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "key_pair",
        f"http://localhost:{moto_server.port}",
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(
    moto_server: MotoServer, this_dir: Path, base_vars: dict[str, Any]
) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)
    Path(base_vars["filename"]).unlink(missing_ok=True)


def test_defaults(ec2: ..., base_vars: dict[str, Any], tf: Terraform):
    tf.apply(vars=base_vars)

    try:
        ec2.KeyPair(base_vars["key_name"]).load()
    except botocore.exceptions.ClientError as exc:
        raise AssertionError from exc

    assert os.path.exists(base_vars["filename"])
