__all__ = ("run_cmd",)


import logging
import shlex
import subprocess

logger = logging.getLogger(__name__)


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

    logger.info("Running command: %s", shlex.join(cmd))

    with subprocess.Popen(cmd, **kwargs) as p:
        if log_output:
            stdout = ""
            for line in p.stdout:
                stdout += line
                logger.debug(line.rstrip())

        maybe_stdout, stderr = p.communicate()

        if not log_output:
            stdout = maybe_stdout

    if check and p.returncode != 0:
        stdout_msg = ""
        stderr_msg = ""
        if p.stdout and not log_output:
            # Print stdout if we have not already done so.
            stdout_msg = f"\nstdout:\n{stdout}"
        if p.stderr:
            stderr_msg = f"\nstderr:\n{stderr}"
        logger.info(
            "Command failed with exit code: %s%s%s",
            p.returncode,
            stdout_msg,
            stderr_msg,
        )
        raise subprocess.CalledProcessError(p.returncode, cmd)

    return subprocess.CompletedProcess(
        p.args,
        p.returncode,
        stdout,
        stderr,
    )
