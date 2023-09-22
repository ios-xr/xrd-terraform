import json
import logging
from pathlib import Path

import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs

logger = logging.getLogger(__name__)


@define
class Outputs(TerraformOutputs):
    role_arn: str


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture(scope="module")
def role_policy(iam):
    doc = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::your-bucket-name",
            },
            {
                "Effect": "Allow",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::your-bucket-name/*",
            },
        ],
    }

    return iam.create_policy(
        PolicyName="YourPolicyName", PolicyDocument=json.dumps(doc)
    )


def test_basic(iam, tf: Terraform, role_policy):
    role_name = "foo"
    oidc_issuer = "https://must.be.an.url"
    oidc_provider = "whatever"
    service_account = "sa"
    namespace = "namespace"

    vars = {
        "role_name": role_name,
        "role_policies": [role_policy.arn],
        "oidc_issuer": oidc_issuer,
        "oidc_provider": oidc_provider,
        "namespace": namespace,
        "service_account": service_account,
    }
    tf.apply(vars=vars)
    outputs = Outputs.from_terraform(tf)
    role = iam.Role("foo")

    assert role.arn == outputs.role_arn

    assert role.assume_role_policy_document == {
        "Statement": [
            {
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        f"{oidc_issuer.lstrip('https://')}:aud": "sts.amazonaws.com"
                    },
                    "StringLike": {
                        f"{oidc_issuer.lstrip('https://')}:sub": f"system:serviceaccount:{namespace}:{service_account}"
                    },
                },
                "Effect": "Allow",
                "Principal": {"Federated": oidc_provider},
            }
        ],
        "Version": "2012-10-17",
    }

    assert role_policy in role.attached_policies.all()
