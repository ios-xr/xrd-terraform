import json
import logging
import uuid
from pathlib import Path
from typing import Any

import pytest
from attrs import define

from ._types import MotoServer, Terraform, TerraformOutputs

logger = logging.getLogger(__name__)


@define
class Outputs(TerraformOutputs):
    role_arn: str


@pytest.fixture(scope="module")
def tf(this_dir: Path, moto_server: MotoServer) -> Terraform:
    tf = Terraform(
        this_dir / "terraform" / "irsa",
        f"http://localhost:{moto_server.port}",
    )
    tf.init(upgrade=True)
    return tf


@pytest.fixture(autouse=True)
def reset(moto_server: MotoServer, this_dir: Path) -> None:
    yield
    moto_server.reset()
    (this_dir / "terraform.tfstate").unlink(missing_ok=True)


@pytest.fixture
def role_policy(iam: ...):
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
        PolicyName="YourPolicyName",
        PolicyDocument=json.dumps(doc),
    )


@pytest.fixture
def base_vars(role_policy: ...) -> dict[str, Any]:
    return {
        "role_name": str(uuid.uuid4()),
        "role_policies": [role_policy.arn],
        "oidc_issuer": f"https://{uuid.uuid4()}.org",
        "oidc_provider": str(uuid.uuid4()),
        "namespace": str(uuid.uuid4()),
        "service_account": str(uuid.uuid4()),
    }


def test_defaults(iam: ..., tf: Terraform, base_vars: dict[str, Any]):
    tf.apply(vars=base_vars)
    outputs = Outputs.from_terraform(tf)

    role = iam.Role(base_vars["role_name"])
    assert role.arn == outputs.role_arn
    assert role.assume_role_policy_document == {
        "Statement": [
            {
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        f"{base_vars['oidc_issuer'].removeprefix('https://')}:aud": "sts.amazonaws.com",
                    },
                    "StringLike": {
                        f"{base_vars['oidc_issuer'].removeprefix('https://')}:sub": f"system:serviceaccount:{base_vars['namespace']}:{base_vars['service_account']}",
                    },
                },
                "Effect": "Allow",
                "Principal": {"Federated": base_vars["oidc_provider"]},
            },
        ],
        "Version": "2012-10-17",
    }
    assert set(base_vars["role_policies"]).issubset(
        {x.arn for x in role.attached_policies.all()},
    )
