import logging
import os
import random
from pathlib import Path

import boto3
import pytest
from moto.server import ThreadedMotoServer
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_eks import EKSClient
from mypy_boto3_iam import IAMServiceResource

from .moto_server import MotoServer

logger = logging.getLogger(__name__)


def pytest_configure(config: pytest.Config) -> None:
    # Avoid overly verbose logging.
    logging.getLogger("boto3").setLevel(logging.INFO)
    logging.getLogger("botocore").setLevel(logging.INFO)
    logging.getLogger("urllib3").setLevel(logging.INFO)
    logging.getLogger("werkzeug").setLevel(logging.WARN)


@pytest.fixture(scope="session", autouse=True)
def moto_server() -> MotoServer:
    # Refer to http://docs.getmoto.org/en/latest/docs/getting_started.html#example-on-usage
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"

    for i, port in enumerate(random.sample(range(50000, 50500), 100)):
        try:
            server = MotoServer(ThreadedMotoServer(port=port))
            server.start()
            yield server
            break
        except Exception:
            if i >= 10:
                raise
            raise
    server.stop()


@pytest.fixture(scope="session")
def ec2(
    request: pytest.FixtureRequest,
    moto_server: MotoServer,
) -> EC2ServiceResource:
    return boto3.resource("ec2", endpoint_url=moto_server.endpoint)


@pytest.fixture(scope="session")
def iam(
    request: pytest.FixtureRequest,
    moto_server: MotoServer,
) -> IAMServiceResource:
    return boto3.resource("iam", endpoint_url=moto_server.endpoint)


@pytest.fixture(scope="session")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def eks_client(
    request: pytest.FixtureRequest,
    moto_server: MotoServer,
) -> EKSClient:
    return boto3.client("eks", endpoint_url=moto_server.endpoint)
