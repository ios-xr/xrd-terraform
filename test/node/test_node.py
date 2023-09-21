from pathlib import Path

import boto3
import pytest
from typing import Any
import requests
from attrs import define

from ..utils import Terraform, TerraformOutputs, MotoServer


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="module")
def ec2() -> None:
    return boto3.resource("ec2")


class TestDefault:
    private_ip_address = "10.0.0.10"
    cluster_name = "test-cluster"
    ami = "ami-03cf127a" 
    name = "foo"

    @property
    def vars(self) -> dict[str, Any]:
        return {"ami": self.ami, "cluster_name":self.cluster_name,
                "private_ip_address": self.private_ip_address,
                "network_interfaces": [], "name":self.name}

    @pytest.fixture(scope="class", autouse=True)
    def apply(self, tf: Terraform) -> None:
        tf.apply(vars=self.vars)

    @pytest.fixture(scope="class", autouse=True)
    def reset(self, moto_server: MotoServer, this_dir: Path) -> None:
        yield
        moto_server.reset()
        (this_dir / "terraform.tfstate").unlink(missing_ok=True)
        (this_dir / "test-cluster-instance.pem").unlink(missing_ok=True)

    @pytest.fixture(scope="class")
    def instance(self, ec2, tf: Terraform):
        outputs = Outputs.from_terraform(tf)
        ret = ec2.Instance(outputs.id)
        ret.load()
        return ret

    def test_key_name(self, instance):
        assert instance.key_name == f"{self.cluster_name}-instance"

    def test_private_ip_address(self, instance):
        assert instance.private_ip_address == self.private_ip_address

    def test_no_source_dest_check(self, instance):
        assert not instance.source_dest_check

    def test_cluster_owned_tag(self, instance):
        expected_tag_key = "kubernetes.io/cluster/test-cluster"
        for tag in instance.tags: 
            if tag["Key"] == expected_tag_key:
                assert tag["Value"] == "owned"
                break
        else:
            assert False, f"tag '{expected_tag_key}' does not exist"

    def test_name_tag(self, instance):
        expected_tag_key = "Name"
        for tag in instance.tags: 
            if tag["Key"] == expected_tag_key:
                assert tag["Value"] == self.name
                break
        else:
            assert False, f"tag '{expected_tag_key}' does not exist"

    def test_no_public_ip_address(self, instance):
        assert not instance.public_ip_address

class TestFoo:
    @pytest.fixture(scope="class", autouse=True)
    def reset(moto_server: MotoServer, this_dir: Path) -> None:
        yield
        moto_server.reset()
        (this_dir / "terraform.tfstate").unlink(missing_ok=True)

