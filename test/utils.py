import requests
import pytest
from moto.server import ThreadedMotoServer
import json
import logging
import shlex
import subprocess
from dataclasses import dataclass
from functools import partial
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any, Callable, Mapping

import cattrs
from attrs import fields
from cattrs.errors import ForbiddenExtraKeysError

logger = logging.getLogger(__name__)


@dataclass
class Terraform:
    working_dir: Path
    endpoint: str

    def init(
        self, *, upgrade: bool = False
    ) -> subprocess.CompletedProcess[str]:
        cmd = ["terraform", f"-chdir={self.working_dir}", "init"]
        if upgrade:
            cmd.append("-upgrade")
        return run_cmd(cmd)

    def apply(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = [
            "terraform",
            f"-chdir={self.working_dir}",
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

        p = run_cmd(cmd)

        if vars:
            var_file.close()

        return p

    def destroy(
        self, vars: dict[str, str] | None = None, auto_approve: bool = True
    ) -> subprocess.CompletedProcess:
        cmd = [
            "terraform",
            f"-chdir={self.working_dir}",
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

        p = run_cmd(cmd)

        if vars:
            var_file.close()

        return p

    def output(self) -> subprocess.CompletedProcess:
        return run_cmd(
            ["terraform", f"-chdir={self.working_dir}", "output", "-json"]
        )


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


def run_cmd(
    cmd: list[str], *, log_output: bool = True, **kwargs
) -> subprocess.CompletedProcess[str]:
    """
    Run a command, capturing stdout and stderr by default, and raising on
    error.

    :param cmd:
        The command to run.

    :param log_output:
        Whether to log the output.

    :param kwargs:
        Passed through to subprocess.run().

    :raises subprocess.CalledProcessError:
        If the command returns non-zero exit status.

    :raises subprocess.TimeoutExpired:
        If timeout is given and the command times out.

    :return:
        Completed process object from subprocess.run().

    """
    logger.debug("Running command: %r", shlex.join(cmd))
    kwargs = {
        "check": True,
        "text": True,
        "encoding": "utf-8",
        **kwargs,
    }
    if not {"stdout", "stderr", "capture_output"}.intersection(
        kwargs
    ) or kwargs.pop("capture_output", False):
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
    elif (
        "stdout" not in kwargs
        and kwargs.get("stderr", None) == subprocess.STDOUT
    ):
        kwargs["stdout"] = subprocess.PIPE

    try:
        p: subprocess.CompletedProcess[str] = subprocess.run(cmd, **kwargs)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        if isinstance(e, subprocess.CalledProcessError):
            issue_desc = "failed"
            rc = e.returncode
            stdout = e.stdout
            stderr = e.stderr
        else:
            issue_desc = "timed out"
            rc = None
            # Workaround for https://github.com/python/cpython/issues/87597,
            # TimeoutExpired gives bytes rather than str.
            if isinstance(e.stdout, bytes):
                stdout = e.stdout.decode("utf-8")
            else:
                stdout = e.stdout
            if isinstance(e.stderr, bytes):
                stderr = e.stderr.decode("utf-8")
            else:
                stderr = e.stderr
        if stderr:
            logger.debug(
                "Command %s with exit code %s, stdout:\n%s\nstderr:\n%s",
                issue_desc,
                rc,
                stdout.strip("\n"),
                stderr.strip("\n"),
            )
        elif stdout:
            logger.debug(
                "Command %s with exit code %s, output:\n%s",
                issue_desc,
                rc,
                stdout.strip("\n"),
            )
        else:
            logger.debug("Command %s with exit code %s", issue_desc, rc)
        raise

    if log_output:
        logger.debug("Command stdout:\n%s", (p.stdout or "").strip("\n"))
        logger.debug("Command stderr:\n%s", (p.stderr or "").strip("\n"))

    return p


def wait_until(
    max_secs: int, interval_secs: int, fn: Callable[..., bool], *args, **kwargs
) -> bool:
    elapsed = 0
    while elapsed < max_secs:
        if fn(*args, **kwargs):
            return True
        time.sleep(interval_secs)
        elapsed += interval_secs
    return False
