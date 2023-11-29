import logging
import random
from pathlib import Path

import boto3
import pytest
from moto.server import ThreadedMotoServer
from mypy_boto3_ec2 import EC2ServiceResource
from mypy_boto3_eks import EKSClient
from mypy_boto3_iam import IAMServiceResource

from ._types import MotoServer

logger = logging.getLogger(__name__)


def pytest_addoption(parser: pytest.Parser) -> None:
    logging_group = parser.getgroup("logging")
    log_dir_description = (
        "The directory to store all logs in, defaults to workspace root"
    )
    logging_group.addoption("--log-dir", help=log_dir_description)
    parser.addini("log_dir", log_dir_description)


def pytest_configure(config: pytest.Config) -> None:
    log_dir = config.getoption("log_dir") or config.getini("log_dir")
    if not log_dir:
        log_dir = Path(__file__).parent / "logs"

    log_dir = Path(log_dir)
    logger.debug("Using log dir %s", log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    (log_dir / ".gitignore").write_text("*")

    log_file = config.getini("log_file")
    if log_file:
        config.option.log_file = str(log_dir / log_file)

    # Avoid overly verbose logging.
    logging.getLogger("boto3").setLevel(logging.INFO)
    logging.getLogger("botocore").setLevel(logging.INFO)
    logging.getLogger("urllib3").setLevel(logging.INFO)
    logging.getLogger("werkzeug").setLevel(logging.WARN)


@pytest.fixture(scope="session", autouse=True)
def moto_server() -> MotoServer:
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
def ec2(moto_server: MotoServer) -> EC2ServiceResource:
    return boto3.resource("ec2", endpoint_url=moto_server.endpoint)


@pytest.fixture(scope="session")
def iam(moto_server: MotoServer) -> IAMServiceResource:
    return boto3.resource("iam", endpoint_url=moto_server.endpoint)


@pytest.fixture(scope="session")
def this_dir() -> Path:
    return Path(__file__).parent


@pytest.fixture(scope="module")
def eks_client(moto_server: MotoServer) -> EKSClient:
    return boto3.client("eks", endpoint_url=moto_server.endpoint)
