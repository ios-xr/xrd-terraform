from typing import Any
from pathlib import Path
import uuid

import boto3
import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs
from . import Outputs


@pytest.fixture(scope="package")
def eks_client(moto_server: MotoServer) -> ...:
    return boto3.client("eks")


@pytest.fixture(scope="package")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="package")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(this_dir, f"http://localhost:{moto_server.port}")
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="package", autouse=True)
def vpc(ec2) -> ...:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture(scope="package", autouse=True)
def subnets(vpc) -> None:
    s1 = vpc.create_subnet(
        AvailabilityZone="eu-west-1a", CidrBlock="10.0.10.0/24"
    )
    s2 = vpc.create_subnet(
        AvailabilityZone="eu-west-1b", CidrBlock="10.0.11.0/24"
    )
    return s1, s2


@pytest.fixture(scope="package", autouse=True)
def sg(ec2, vpc) -> None:
    sg = ec2.create_security_group(
        GroupName="ssh", Description="ssh", VpcId=vpc.vpc_id
    )
    sg.authorize_ingress(
        IpProtocol="tcp",
        FromPort=22,
        ToPort=22,
        CidrIp="0.0.0.0/0",
    )
    return sg


@pytest.fixture(scope="package")
def base_vars(subnets):
    return {
        "cluster_version": "1.27",
        "name": str(uuid.uuid4()),
        "subnet_ids": [subnets[0].id, subnets[1].id],
    }
