from pathlib import Path
from typing import Any

import boto3
import pytest

from ..utils import MotoServer, Terraform


@pytest.fixture(scope="package")
def iam() -> None:
    return boto3.resource("iam")


@pytest.fixture(scope="package")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="package")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf
