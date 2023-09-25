import base64
import logging
from pathlib import Path
from typing import Any

import pytest
from attrs import define

from ..utils import MotoServer, Terraform, TerraformOutputs

logger = logging.getLogger(__name__)


@define
class Outputs(TerraformOutputs):
    id: str
    private_ip: str
