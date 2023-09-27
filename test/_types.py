__all__ = (
    "MotoServer",
    "Terraform",
    "TerraformOutputs",
)

import json
import logging
import os
import subprocess
from functools import partial
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any, Mapping

import cattrs
import requests
from attrs import define, fields
from cattrs.errors import ForbiddenExtraKeysError
from moto.server import ThreadedMotoServer

from .utils import run_cmd

logger = logging.getLogger(__name__)


@define
class Terraform:
    working_dir: Path
    endpoint: str
    data_dir: Path | None = None

    def _run_terraform_cmd(
        self, cmd: list[str], **kwargs
    ) -> subprocess.CompletedProcess[str]:
        cmd = ["terraform", f"-chdir={self.working_dir}", *cmd]
        env = os.environ.copy()
        if self.data_dir:
            env["TF_DATA_DIR"] = self.data_dir
        return run_cmd(cmd, env=env, **kwargs)

    def init(
        self, *, upgrade: bool = False
    ) -> subprocess.CompletedProcess[str]:
        cmd = ["init"]
        if upgrade:
            cmd.append("-upgrade")
        return self._run_terraform_cmd(cmd)

    def apply(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = [
            "apply",
            "-no-color",
            f"-var=endpoint={self.endpoint}",
        ]

        if vars:
            var_file = NamedTemporaryFile(mode="w", suffix=".json")
            json.dump(vars, var_file)
            var_file.flush()
            cmd.append(f"-var-file={var_file.name}")

        if auto_approve:
            cmd.append("-auto-approve")

        p = self._run_terraform_cmd(cmd)

        if vars:
            var_file.close()

        return p

    def destroy(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = [
            "destroy",
            "-no-color",
            f"-var=endpoint={self.endpoint}",
        ]

        if vars:
            var_file = NamedTemporaryFile(mode="w", suffix=".json")
            json.dump(vars, var_file)
            var_file.flush()
            cmd.append(f"-var-file={var_file.name}")

        if auto_approve:
            cmd.append("-auto-approve")

        p = self._run_terraform_cmd(cmd)

        if vars:
            var_file.close()

        return p

    def output(self) -> subprocess.CompletedProcess:
        return self._run_terraform_cmd(["output", "-json"])


class TerraformOutputs:
    def structure(
        c, d: Mapping[str, Any], t: "TerraformOutputs"
    ) -> "TerraformOutputs":
        conv_obj = {}
        for a in fields(t):
            value = d.pop(a.name)["value"]
            conv_obj[a.name] = c.structure(value, a.type)
        if d:
            raise ForbiddenExtraKeysError("", t, set(d.keys()))
        return t(**conv_obj)

    @classmethod
    def from_terraform(cls, tf: Terraform):
        out = tf.output().stdout
        d = json.loads(out)
        converter = cattrs.Converter()
        converter.register_structure_hook(
            cls, partial(cls.structure, converter)
        )
        return converter.structure(d, cls)


@define
class MotoServer:
    _server: ThreadedMotoServer

    @property
    def port(self) -> int:
        return self._server._port

    @property
    def endpoint(self) -> str:
        return f"http://localhost:{self.port}"

    def start(self, *args, **kwargs) -> None:
        return self._server.start(*args, **kwargs)

    def stop(self, *args, **kwargs) -> None:
        return self._server.stop(*args, **kwargs)

    def reset(self):
        requests.post(f"{self.endpoint}/moto-api/reset")
