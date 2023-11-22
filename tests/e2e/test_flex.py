from pathlib import Path

import pytest

from terraform import Terraform
from utils import run_cmd


@pytest.fixture(scope="module")
def flex(examples_dir: Path) -> Terraform:
    return Terraform(examples_dir.parent / "dev" / "flex")


@pytest.fixture(scope="module", autouse=True)
def create_flex(
    create_bootstrap: None,
    flex: Terraform,
) -> None:
    vars={"node_count": 1, "interface_count": 1, "xr_root_user": "user", "xr_root_password": "password"}
    flex.init()
    try:
        flex.apply(vars=vars)
        yield
    finally:
        flex.destroy(vars=vars)


def test_smoke():
    # The Flex configuration does not create the workload; just check that we
    # can apply and destroy it without issue.
    pass
