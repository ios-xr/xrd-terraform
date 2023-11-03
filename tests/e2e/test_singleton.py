from pathlib import Path

import pytest

from terraform import Terraform
from utils import run_cmd


@pytest.fixture(scope="module")
def infra(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir / "singleton" / "infra")


@pytest.fixture(scope="module")
def workload(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir / "singleton" / "workload")


@pytest.fixture(scope="module", autouse=True)
def create_singleton(
    create_bootstrap: None,
    infra: Terraform,
    workload: Terraform,
) -> None:
    infra.init()
    workload.init()
    try:
        infra.apply()
        workload.apply()
        yield
    finally:
        workload.destroy()
        infra.destroy()


def test_smoke():
    run_cmd(
        [
            "kubectl",
            "rollout",
            "status",
            "sts/xrd-xrd-vrouter",
            "--timeout=1m",
        ],
    )
