import json
import logging
import string
from dataclasses import dataclass
from ipaddress import IPv4Network
from pathlib import Path
from typing import Literal, TypeVar

import boto3
import pytest
import requests
from hypothesis import Phase, given, settings
from hypothesis.strategies import (
    booleans,
    composite,
    dictionaries,
    integers,
    lists,
    sets,
    text,
)

from ..utils import Terraform

logger = logging.getLogger(__name__)

logging.getLogger("boto3").setLevel("INFO")
logging.getLogger("botocore").setLevel("INFO")


T = TypeVar("T")


def element(xs: list[T], i: int) -> T:
    return xs[i % len(xs)]


@dataclass
class Gateway:
    id: str
    type: Literal["Internet", "NAT"]


@dataclass
class Subnet:
    id: str
    az: str
    cidr_block: IPv4Network
    name: str
    tags: dict[str, str]
    gateway: Gateway | None = None

    def assert_exists(self, ec2, vpc) -> None:
        logger.info("Checking subnet %r exists", self)
        try:
            subnet = list(vpc.subnets.filter(SubnetIds=[self.id]))[0]
        except KeyError:
            raise AssertionError(
                f"Could not find subnet {self.id} in VPC {vpc.vpc_id}"
            )

        assert subnet.availability_zone == self.az
        assert IPv4Network(subnet.cidr_block) == self.cidr_block

        tags = {x["Key"]: x["Value"] for x in subnet.tags}
        assert tags == self.tags | {"Name": self.name}

        if self.gateway:
            rtbs = ec2.describe_route_tables(
                Filters=[
                    {
                        "Name": "association.subnet-id",
                        "Values": [self.id],
                    },
                ]
            )["RouteTables"]

            # A subnet is associated with exactly one route table, either
            # explicitly or implictly.
            assert len(rtbs) == 1

            default_route_found = False
            for route in rtbs[0]["Routes"]:
                if route["DestinationCidrBlock"] == "0.0.0.0/0":
                    assert not default_route_found
                    default_route_found = True
                    assert (
                        route.get("GatewayId", route.get("NatGatewayId"))
                        == self.gateway
                    )

            assert default_route_found


@dataclass
class Subnets:
    cidr_blocks: list[IPv4Network]
    names: list[str]
    suffix: str
    tags: dict[str, str]

    def to_var_file(self, prefix: str) -> dict:
        return {
            f"{prefix}_subnets": [
                str(cidr_block) for cidr_block in self.cidr_blocks
            ],
            f"{prefix}_subnet_names": self.names,
            f"{prefix}_subnet_suffix": self.suffix,
            f"{prefix}_subnet_tags": self.tags,
        }


@dataclass
class Inputs:
    azs: list[str]
    create_igw: bool
    enable_nat_gateway: bool
    public_subnets: Subnets
    private_subnets: Subnets
    intra_subnets: Subnets

    def to_var_file(self):
        return {
            "azs": self.azs,
            "create_igw": True,
            "enable_nat_gateway": True,
            **self.public_subnets.to_var_file("public"),
            **self.private_subnets.to_var_file("private"),
            **self.intra_subnets.to_var_file("intra"),
        }


def create_subnets(
    ids: list[str],
    azs: list[str],
    cidr_blocks: list[IPv4Network],
    names: list[str],
    suffix: str,
    tags: dict[str, str],
    gateways: list[str] | None = None,
) -> list[Subnet]:
    ret = []
    for i, id in enumerate(ids):
        az = azs[i % len(azs)]
        cidr_block = cidr_blocks[i]
        if i < len(names):
            name = names[i]
        else:
            name = f"-{suffix}-{az}"
        gw = element(gateways, i) if gateways else None
        ret.append(Subnet(id, az, cidr_block, name, tags, gw))
    return ret


@dataclass
class Outputs:
    vpc_id: str
    subnets: list[Subnet]

    @classmethod
    def from_terraform_output(cls, inputs: Inputs, output: str):
        d = json.loads(output)
        igw_id = d["igw_id"]["value"] if "igw_id" in d else None
        subnets = []
        subnets.extend(
            create_subnets(
                d["public_subnet_ids"]["value"],
                inputs.azs,
                [
                    IPv4Network(x)
                    for x in d["public_subnet_cidr_blocks"]["value"]
                ],
                inputs.public_subnets.names,
                inputs.public_subnets.suffix,
                inputs.public_subnets.tags,
                [igw_id] if igw_id else None,
            )
        )
        subnets.extend(
            create_subnets(
                d["private_subnet_ids"]["value"],
                inputs.azs,
                [
                    IPv4Network(x)
                    for x in d["private_subnet_cidr_blocks"]["value"]
                ],
                inputs.private_subnets.names,
                inputs.private_subnets.suffix,
                inputs.private_subnets.tags,
                d["natgw_ids"]["value"] or None,
            )
        )
        subnets.extend(
            create_subnets(
                d["intra_subnet_ids"]["value"],
                inputs.azs,
                [
                    IPv4Network(x)
                    for x in d["intra_subnet_cidr_blocks"]["value"]
                ],
                inputs.intra_subnets.names,
                inputs.intra_subnets.suffix,
                inputs.intra_subnets.tags,
            )
        )
        return cls(d["vpc_id"]["value"], subnets)


words = text(alphabet=string.ascii_letters)
nonempty_words = text(alphabet=string.ascii_letters, min_size=1)


@composite
def cidr_blocks(
    draw, cidr: IPv4Network, prefix: int, size: int
) -> set[IPv4Network]:
    candidates = list(cidr.subnets(new_prefix=prefix))
    assert size < len(candidates)
    indexes = draw(
        sets(
            integers(min_value=0, max_value=len(candidates) - 1),
            min_size=size,
            max_size=size,
        )
    )
    return {candidates[i] for i in indexes}


@composite
def inputs(draw):
    azs = ["eu-west-1a", "eu-west-1b"]
    create_igw = draw(booleans())
    enable_nat_gateways = draw(booleans())

    public_subnet_count = draw(integers(min_value=0, max_value=4))
    private_subnet_count = draw(integers(min_value=0, max_value=4))
    intra_subnet_count = draw(integers(min_value=0, max_value=4))
    subnet_count = (
        public_subnet_count + private_subnet_count + intra_subnet_count
    )

    cidrs = list(
        draw(cidr_blocks(IPv4Network("10.0.0.0/16"), 24, subnet_count))
    )

    public_subnets = Subnets(
        cidr_blocks={cidrs.pop() for _ in range(public_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    private_subnets = Subnets(
        cidr_blocks={cidrs.pop() for _ in range(private_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    intra_subnets = Subnets(
        cidr_blocks={cidrs.pop() for _ in range(intra_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    return Inputs(
        azs,
        create_igw,
        enable_nat_gateways,
        public_subnets,
        private_subnets,
        intra_subnets,
    )


@pytest.fixture(scope="module")
def this_dir() -> Path:
    return Path(__file__).parent
    return this_dir.parent.parent / "modules" / "aws" / "vpc"


@pytest.fixture(scope="module")
def tf(this_dir: Path):
    tf = Terraform(this_dir)
    tf.init(upgrade=True)
    return tf


@pytest.fixture(scope="module")
def ec2():
    return boto3.client("ec2", endpoint_url="http://localhost:5000")


@given(inputs())
@settings(
    deadline=None, max_examples=50, phases=(Phase.generate, Phase.target)
)
def test_foo(ec2, this_dir: Path, tf: Terraform, inputs: Inputs):
    with (this_dir / "terraform.tfvars.json").open("w") as f:
        json.dump(inputs.to_var_file(), f)
    try:
        logger.info("Applying with inputs %r", inputs)
        tf.apply()
        outputs = Outputs.from_terraform_output(inputs, tf.output().stdout)
        vpc = boto3.resource("ec2", endpoint_url="http://localhost:5000").Vpc(
            outputs.vpc_id
        )
        logger.debug("%r", list(vpc.subnets.all()))
        for subnet in outputs.subnets:
            subnet.assert_exists(ec2, vpc)

    finally:
        requests.post("http://localhost:5000/moto-api/reset")
        (this_dir / "terraform.tfstate").unlink(missing_ok=True)
