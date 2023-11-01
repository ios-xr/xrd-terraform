import uuid
from pathlib import Path

import pytest
from attrs import define
from moto_server import MotoServer
from mypy_boto3_ec2 import EC2ServiceResource

from terraform import Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    azs: str
    igw_id: str
    intra_subnet_cidr_blocks: list[str]
    intra_subnet_ids: list[str]
    name: str
    nat_public_ips: list[str]
    natgw_ids: list[str]
    private_subnet_cidr_blocks: list[str]
    private_subnet_ids: list[str]
    public_subnet_cidr_blocks: list[str]
    public_subnet_ids: list[str]
    vpc_cidr_block: str
    vpc_id: str


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "vpc",
        f"http://localhost:{moto_server.port}",
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


def test_public_and_private_subnets(ec2: EC2ServiceResource, tf: Terraform):
    """
    Check that creating a VPC with one public and one private subnet is
    successful.  This is similar to the recommended VPC for EKS described
    here: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html,
    and is used as a base VPC for all example configurations.

    """
    azs = [
        x["ZoneName"]
        for x in ec2.meta.client.describe_availability_zones(
            Filters=[{"Name": "state", "Values": ["available"]}],
        )["AvailabilityZones"]
    ][:2]

    vars = {
        "name": str(uuid.uuid4()),
        "azs": azs,
        "cidr": "10.0.0.0/16",
        "enable_dns_hostnames": True,
        "enable_nat_gateway": True,
        "private_subnets": ["10.0.0.0/24"],
        "public_subnets": ["10.0.200.0/24"],
        "map_public_ip_on_launch": True,
    }

    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)

    # The following resources should be created:
    #   - The VPC.
    #   - A public and a private subnet.
    #   - An IGW.
    #   - A NAT GW.
    #   - A route table associated with the public subnet, with default route
    #     via the IGW.
    #   - A route table associated with the private subnet, with default route
    #     via the NAT GW.

    vpc = ec2.Vpc(outputs.vpc_id)
    assert vpc.cidr_block == "10.0.0.0/16"

    assert len(outputs.public_subnet_ids) == 1
    public_subnet = ec2.Subnet(outputs.public_subnet_ids[0])
    assert public_subnet.cidr_block == "10.0.200.0/24"
    assert public_subnet.map_public_ip_on_launch

    resp = ec2.meta.client.describe_route_tables(
        Filters=[
            {
                "Name": "association.subnet-id",
                "Values": [
                    public_subnet.id,
                ],
            },
        ],
    )
    rtb_id = resp["RouteTables"][0]["Associations"][0]["RouteTableId"]
    rtb = ec2.RouteTable(rtb_id)
    for route in rtb.routes_attribute:
        if route["DestinationCidrBlock"] == "0.0.0.0/0":
            assert route.get("GatewayId") == outputs.igw_id
            break
    else:
        raise AssertionError(f"no default route in '{rtb.id}'")

    assert len(outputs.private_subnet_ids) == 1
    private_subnet = ec2.Subnet(outputs.private_subnet_ids[0])
    assert private_subnet.cidr_block == "10.0.0.0/24"

    resp = ec2.meta.client.describe_route_tables(
        Filters=[
            {
                "Name": "association.subnet-id",
                "Values": [
                    private_subnet.id,
                ],
            },
        ],
    )
    rtb_id = resp["RouteTables"][0]["Associations"][0]["RouteTableId"]
    rtb = ec2.RouteTable(rtb_id)
    for route in rtb.routes_attribute:
        if route["DestinationCidrBlock"] == "0.0.0.0/0":
            assert route.get("NatGatewayId") == outputs.natgw_ids[0]
            break
    else:
        raise AssertionError(f"no default route in '{rtb.id}'")
