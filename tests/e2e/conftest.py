from pathlib import Path

import pytest
from common.utils import Terraform


@pytest.fixture(scope="session")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="session")
def examples_dir(this_dir: Path) -> Path:
    return this_dir.parent.parent / "examples"


@pytest.fixture(scope="session")
def bootstrap(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir / "bootstrap")


@pytest.fixture(scope="session")
def create_bootstrap(bootstrap: Terraform) -> None:
    bootstrap.init()
    try:
        bootstrap.apply()
        yield
    finally:
        bootstrap.destroy()
