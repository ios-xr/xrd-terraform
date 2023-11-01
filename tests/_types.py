__all__ = ("Terraform",)

import json
import os
import subprocess
from pathlib import Path
from tempfile import NamedTemporaryFile

from attrs import define

from .utils import run_cmd


@define
class Terraform:
    """
    Wrapper for the Terraform CLI.

    ..attribute:: working_dir
        Terraform working directory.

    ..attribute:: endpoint
        Endpoint URL to use for all services in the AWS provider
        configuration.
        Refer to https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/custom-service-endpoints.

    ..attribute:: data_dir
        Terraform data directory.
        Refer to https://developer.hashicorp.com/terraform/cli/config/environment-variables#tf_data_dir.

    """

    working_dir: Path
    endpoint: str
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
        cmd = ["init"]
        if upgrade:
            cmd.append("-upgrade")
        return self._run_terraform_cmd(cmd)

    def apply(
        self,
        vars: dict[str, str] | None = None,
        auto_approve: bool = True,
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

    def output(self) -> subprocess.CompletedProcess:
        return self._run_terraform_cmd(["output", "-json"])
