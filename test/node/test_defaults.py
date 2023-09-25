from pathlib import Path
from typing import Any

import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str


@pytest.fixture(scope="module", autouse=True)
def apply(tf: Terraform, base_vars: dict[str, Any]) -> None:
    tf.apply(vars=base_vars)


@pytest.fixture(scope="module", autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)
    (this_dir / "test-cluster-instance.pem").unlink(missing_ok=True)


@pytest.fixture(scope="module")
def instance(ec2, tf: Terraform):
    outputs = Outputs.from_terraform(tf)
    return ec2.Instance(outputs.id)


def test_key_name(base_vars, instance):
    assert instance.key_name == f"{base_vars['cluster_name']}-instance"


def test_private_ip_address(base_vars, instance):
    assert instance.private_ip_address == base_vars["private_ip_address"]


def test_no_source_dest_check(instance):
    assert not instance.source_dest_check


def test_cluster_owned_tag(base_vars, instance):
    expected_tag_key = "kubernetes.io/cluster/test-cluster"
    for tag in instance.tags:
        if tag["Key"] == expected_tag_key:
            assert tag["Value"] == "owned"
            break
    else:
        assert False, f"tag '{expected_tag_key}' does not exist"


def test_name_tag(base_vars, instance):
    expected_tag_key = "Name"
    for tag in instance.tags:
        if tag["Key"] == expected_tag_key:
            assert tag["Value"] == base_vars["name"]
            break
    else:
        assert False, f"tag '{expected_tag_key}' does not exist"


def test_no_public_ip_address(instance):
    assert not instance.public_ip_address
