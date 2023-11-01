__all__ = ("run_cmd",)

import json
import logging
import os
import subprocess
from pathlib import Path
from tempfile import NamedTemporaryFile

from attrs import define

logger = logging.getLogger(__name__)


@define
class Terraform:
    """
    Wrapper for the Terraform CLI.

    ..attribute:: working_dir
        Terraform working directory.

    ..attribute:: vars
        Variables to pass to `plan`, `apply`, and `destroy`.

    ..attribute:: data_dir
        Terraform data directory.
        Refer to https://developer.hashicorp.com/terraform/cli/config/environment-variables#tf_data_dir.

    """

    working_dir: Path
    vars: dict[str, str] | None = None
    data_dir: Path | None = None

    def _run_terraform_cmd(
        self,
        cmd: list[str],
        **kwargs,
    ) -> subprocess.CompletedProcess[str]:
        """
        Run a Terraform subcommand.

        :param cmd:
            The subcommand to run (i.e. arguments to pass to ``terraform``).

        :param kwargs:
            Passed to `run_cmd`.

        """
        cmd = ["terraform", f"-chdir={self.working_dir}", *cmd]
        env = os.environ.copy()
        if self.data_dir:
            env["TF_DATA_DIR"] = self.data_dir
        return run_cmd(cmd, env=env, **kwargs)

    def init(
        self,
        *,
        upgrade: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        cmd = ["init", "-no-color"]
        if upgrade:
            cmd.append("-upgrade")
        return self._run_terraform_cmd(cmd)

    def apply(
        self,
        vars: dict[str, str] | None = None,
        auto_approve: bool = True,
    ) -> subprocess.CompletedProcess:
        cmd = ["apply", "-no-color"]

        vars = (self.vars or dict()) | (vars or dict())
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
        self,
        vars: dict[str, str] | None = None,
        auto_approve: bool = True,
    ) -> subprocess.CompletedProcess:
        cmd = ["destroy", "-no-color"]

        vars = (self.vars or dict()) | (vars or dict())
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


def run_cmd(
    cmd: list[str],
    *,
    check: bool = True,
    log_output: bool = True,
    **kwargs,
) -> subprocess.CompletedProcess[str]:
    kwargs = {
        "bufsize": 1,
        "encoding": "utf-8",
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "text": True,
        **kwargs,
    }

    with subprocess.Popen(cmd, **kwargs) as p:
        if log_output:
            for line in p.stdout:
                logger.debug(line.rstrip())

    if check and p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)

    return subprocess.CompletedProcess(
        p.args,
        p.returncode,
        p.stdout,
        p.stderr,
    )
