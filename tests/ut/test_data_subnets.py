import uuid
from pathlib import Path
from typing import Any

import pytest
from attrs import define
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_ec2.service_resource import Vpc

from terraform import Terraform, TerraformOutputs

from .moto_server import MotoServer


@define
class Outputs(TerraformOutputs):
    cidr_blocks: dict[str, str]
    ids: dict[str, str]
    names: list[str]
    security_group_id: str
    bastion_security_group_id: str


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "data-subnets",
        vars={"aws_endpoint": f"http://localhost:{moto_server.port}"},
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(
    moto_server: MotoServer,
    this_dir: Path,
    base_vars: dict[str, Any],
) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture
def vpc(ec2) -> Vpc:
    return ec2.create_vpc(CidrBlock="10.0.0.0/16")


@pytest.fixture
def base_vars(this_dir: Path, vpc: Vpc) -> dict[str, Any]:
    availability_zone = "eu-west-1a"
    name_prefix = str(uuid.uuid4())
    vpc_id = vpc.vpc_id
    return {
        "availability_zone": availability_zone,
        "name_prefix": name_prefix,
        "vpc_id": vpc_id,
    }


def test_subnet_count(
    ec2: EC2ServiceResource,
    tf: Terraform,
    base_vars: dict[str, Any],
    vpc: Vpc,
):
    vars = base_vars | {"subnet_count": 4}
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)

    for subnet_name in outputs.names:
        subnet_id = outputs.ids[subnet_name]
        cidr_block = outputs.cidr_blocks[subnet_name]
        subnet = ec2.Subnet(subnet_id)
        assert subnet.cidr_block == cidr_block
        assert subnet.vpc_id == vpc.vpc_id

    sg = ec2.SecurityGroup(outputs.security_group_id)
    assert len(sg.ip_permissions) == 1
    ingress_sgr = sg.ip_permissions[0]
    assert len(sg.ip_permissions_egress) == 1
    egress_sgr = sg.ip_permissions_egress[0]
    for sgr in (ingress_sgr, egress_sgr):
        assert sgr["IpProtocol"] == "-1"
        assert sgr["IpRanges"] == []
        assert sgr["Ipv6Ranges"] == []
        assert sgr["PrefixListIds"] == []
        assert len(sgr["UserIdGroupPairs"]) == 2
        # Expect two different groups, one in basion security group and the
        # other in its own security group.
        assert (
            {
                sgr["UserIdGroupPairs"][0]["GroupId"],
                sgr["UserIdGroupPairs"][1]["GroupId"],
            } == {
                outputs.security_group_id,
                outputs.bastion_security_group_id,
            }
        )
