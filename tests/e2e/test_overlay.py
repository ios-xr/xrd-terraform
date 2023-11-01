from pathlib import Path

import pytest

from common.utils import Terraform, run_cmd


@pytest.fixture(scope="module")
def infra(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir / "overlay" / "infra")


@pytest.fixture(scope="module")
def workload(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir / "overlay" / "workload")


@pytest.fixture(scope="module", autouse=True)
def create_overlay(
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
    run_cmd(["kubectl", "rollout", "status", "sts/xrd1-xrd-vrouter", "--timeout=1m"])
    run_cmd(["kubectl", "rollout", "status", "sts/xrd2-xrd-vrouter", "--timeout=1m"])
