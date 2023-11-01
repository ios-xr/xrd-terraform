import logging
from pathlib import Path

import pytest


def pytest_configure(config: pytest.Config) -> None:
    # Avoid overly verbose logging.
    logging.getLogger("boto3").setLevel(logging.INFO)
    logging.getLogger("botocore").setLevel(logging.INFO)
    logging.getLogger("urllib3").setLevel(logging.INFO)
    logging.getLogger("werkzeug").setLevel(logging.WARN)
