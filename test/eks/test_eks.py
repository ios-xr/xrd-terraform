from pathlib import Path

import boto3
import pytest
from attrs import define

from ..utils import Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    subnet_one_id: str
    subnet_two_id: str


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server._port}")
    tf.init(upgrade=True)
    return tf


def check_cluster(name: str, version: str, endpoint_public_access: bool, endpoint_private_access: bool, security_group_ids: list[str] | None = None):
    eks = boto3.client("eks")
    resp = eks.describe_cluster(name=name)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200
    cluster = resp["cluster"]
    assert cluster["name"] == name
    assert cluster["version"] == version
    assert cluster["resourcesVpcConfig"]["endpointPublicAccess"] == endpoint_public_access
    assert cluster["resourcesVpcConfig"]["endpointPrivateAccess"] == endpoint_private_access
    if security_group_ids:
        assert set(cluster["resourcesVpcConfig"]["securityGroupIds"]) == set(security_group_ids)
    else:
        assert len(cluster["resourcesVpcConfig"]["securityGroupIds"]) == 0


def test_instance_exists(tf: Terraform):
    tf.apply(vars={"name": "foo", "cluster_version": "1.27"})
    check_cluster("foo", "1.27", True, True)
