import logging
from pathlib import Path

import pytest

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
