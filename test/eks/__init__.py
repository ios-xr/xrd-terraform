from pathlib import Path

import boto3
import botocore.errorfactory
import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs


@define
class Outputs(TerraformOutputs):
    subnet_one_id: str
    subnet_two_id: str


@define
class Cluster:
    name: str
    version: str
    endpoint_public_access: bool
    endpoint_private_access: bool
    security_group_ids: set[str]

    @classmethod
    def from_name(cls, eks_client: ..., name: str):
        try:
            resp = eks_client.describe_cluster(name=name)
        except botocore.errorfactory.ResourceNotFoundException:
            return None

        if resp["ResponseMetadata"]["HTTPStatusCode"] != 200:
            return None

        cluster = resp["cluster"]

        return cls(
            name,
            cluster["version"],
            cluster["resourcesVpcConfig"]["endpointPublicAccess"],
            cluster["resourcesVpcConfig"]["endpointPrivateAccess"],
            set(cluster["resourcesVpcConfig"]["securityGroupIds"]),
        )
