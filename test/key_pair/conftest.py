import uuid
from pathlib import Path
from typing import Any

import pytest

from ..utils import Terraform


@pytest.fixture(scope="package")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="package")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="package")
def base_vars(this_dir: Path) -> dict[str, Any]:
    key_name = str(uuid.uuid4())
    return {
        "key_name": key_name,
        "filename": str(this_dir / f"{key_name}.pem"),
    }
