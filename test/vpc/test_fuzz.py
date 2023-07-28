import json
import logging
from dataclasses import dataclass
from ipaddress import IPv4Network
from pathlib import Path

import boto3
import pytest
from hypothesis import Phase, given, settings
from hypothesis.strategies import (
    characters,
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


def get_subnet(
    ec2,
    vpc_id: str,
    cidr_block: IPv4Network,
    name: str,
    tags: dict[str, str] | None = None,
) -> str | None:
    filters = [
        {"Name": "vpc-id", "Values": [vpc_id]},
        {"Name": "cidr-block", "Values": [str(cidr_block)]},
    ]

    tags = (tags or dict()) | {"Name": name}
    filters.extend(
        [{"Name": f"tag:{k}", "Values": [v]} for k, v in tags.items()]
    )

    subnets = ec2.describe_subnets(Filters=filters)["Subnets"]
    if len(subnets) == 1:
        return subnets[0]["SubnetId"]


@dataclass
class PublicSubnets:
    cidr_blocks: list[IPv4Network]
    names: list[str]
    suffix: str
    tags: dict[str, str]

    def check(self, ec2, azs: list[str], vpc_id: str) -> bool:
        for i, cidr_block in enumerate(self.cidr_blocks):
            if i < len(self.names):
                name = self.names[i]
            else:
                az = azs[i % len(azs)]
                name = f"-{az}"
            subnet_id = get_subnet(ec2, vpc_id, name, self.tags)
            assert subnet_id


@dataclass
class PrivateSubnets:
    cidr_blocks: list[IPv4Network]
    names: list[str]
    suffix: str
    tags: dict[str, str]

    def check(self, ec2, azs: list[str], vpc_id: str) -> bool:
        for i, cidr_block in enumerate(self.cidr_blocks):
            if i < len(self.names):
                name = self.names[i]
            else:
                az = azs[i % len(azs)]
                name = f"-{az}"
            subnet_id = get_subnet(ec2, vpc_id, name, self.tags)
            assert subnet_id


@dataclass
class IntraSubnets:
    cidr_blocks: list[IPv4Network]
    names: list[str]
    suffix: str
    tags: dict[str, str]

    def check(self, ec2, azs: list[str], vpc_id: str) -> bool:
        for i, cidr_block in enumerate(self.cidr_blocks):
            if i < len(self.names):
                name = self.names[i]
            else:
                az = azs[i % len(azs)]
                name = f"-{az}"
            subnet_id = get_subnet(ec2, vpc_id, name, self.tags)
            assert subnet_id


@dataclass
class Inputs:
    azs: list[str]
    public_subnets: PublicSubnets
    private_subnets: PrivateSubnets
    intra_subnets: IntraSubnets

    def to_var_file(self):
        return {
            "azs": self.azs,
            **subnets_to_var_file(self.public_subnets),
            **subnets_to_var_file(self.private_subnets),
            **subnets_to_var_file(self.intra_subnets),
        }

    def check(self, ec2, vpc_id: str) -> bool:
        self.public_subnets.check(ec2, self.azs, vpc_id)
        self.private_subnets.check(ec2, self.azs, vpc_id)
        self.intra_subnets.check(ec2, self.azs, vpc_id)


def subnets_to_var_file(
    subnets: PublicSubnets | PrivateSubnets | IntraSubnets,
):
    if isinstance(subnets, PublicSubnets):
        prefix = "public"
    elif isinstance(subnets, PrivateSubnets):
        prefix = "private"
    elif isinstance(subnets, IntraSubnets):
        prefix = "intra"
    else:
        assert False
    return {
        f"{prefix}_subnets": [
            str(cidr_block) for cidr_block in subnets.cidr_blocks
        ],
        f"{prefix}_subnet_names": subnets.names,
        f"{prefix}_subnet_suffix": subnets.suffix,
        f"{prefix}_subnet_tags": subnets.tags,
    }



words = text(alphabet=characters(whitelist_categories=["Ll", "Lu", "Nd"]))
nonempty_words = text(
    alphabet=characters(whitelist_categories=["Ll", "Lu"]), min_size=1
)


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

    public_subnet_count = draw(integers(min_value=0, max_value=4))
    private_subnet_count = draw(integers(min_value=0, max_value=4))
    intra_subnet_count = draw(integers(min_value=0, max_value=4))
    subnet_count = (
        public_subnet_count + private_subnet_count + intra_subnet_count
    )

    cidrs = list(
        draw(cidr_blocks(IPv4Network("10.0.0.0/16"), 24, subnet_count))
    )

    public_subnets = PublicSubnets(
        cidr_blocks={cidrs.pop() for _ in range(public_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    private_subnets = PrivateSubnets(
        cidr_blocks={cidrs.pop() for _ in range(private_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    intra_subnets = IntraSubnets(
        cidr_blocks={cidrs.pop() for _ in range(intra_subnet_count)},
        names=draw(lists(words, max_size=4)),
        suffix=draw(words),
        tags=draw(dictionaries(nonempty_words, nonempty_words, max_size=4)),
    )

    return Inputs(azs, public_subnets, private_subnets, intra_subnets)


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
    deadline=None, max_examples=10, phases=(Phase.generate, Phase.target)
)
def test_foo(ec2, this_dir: Path, tf: Terraform, inputs: Inputs):
    logger.debug("%r", inputs.to_var_file())
    with (this_dir / "terraform.tfvars.json").open("w") as f:
        json.dump(inputs.to_var_file(), f)
    try:
        tf.apply()
        out = tf.output().stdout
        vpc_id = json.loads(out)["vpc_id"]["value"]
        inputs.check(ec2, vpc_id)
    finally:
        tf.destroy()
