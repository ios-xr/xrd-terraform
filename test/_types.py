# _types.py

__all__ = (
    "Image",
    "Kubectl",
    "KubernetesVersion",
    "Platform",
)

import dataclasses
import enum
import subprocess
from typing import Callable


class KubernetesVersion(str, enum.Enum):
    V1_23 = "1.23"
    V1_24 = "1.24"
    V1_25 = "1.25"
    V1_26 = "1.26"
    V1_27 = "1.27"

    @classmethod
    def latest(cls):
        return cls.V1_27

    def __str__(self):
        return self.value


class Platform(str, enum.Enum):
    XRD_CONTROL_PLANE = "xrd-control-plane"
    XRD_VROUTER = "xrd-vrouter"

    def __str__(self):
        return self.value


@dataclasses.dataclass
class Image:
    platform: Platform
    repository: str
    tag: str


Kubectl = Callable[..., subprocess.CompletedProcess[str]]
