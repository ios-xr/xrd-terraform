import datetime as dt
import logging
from pathlib import Path

import pytest

logger = logging.getLogger(__name__)


def pytest_configure(config: pytest.Config) -> None:
    if not config.getoption("log_file"):
        log_dir = Path("logs")
        log_dir.mkdir(parents=True, exist_ok=True)
        (log_dir / ".gitignore").write_text("*")
        log_file = (
            log_dir
            / f"xrd_terraform_tests.log.{dt.datetime.now().strftime(r'%Y%m%d_%H%M%S')}"
        )
        config.option.log_file = str(log_file)
