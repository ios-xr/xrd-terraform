__all__ = (
    "run_cmd",
)


import shlex
import logging
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
            for line in p.stdout:
                logger.info(line.rstrip())

    if check and p.returncode != 0:
        stdout = ""
        stderr = ""
        if p.stdout and not log_output:
            # Print stdout if we have not already done so.
            stdout = f"\nstdout:\n{p.stdout}"
        if p.stderr:
            stderr = f"\nstderr:\n{p.stderr}"
        logger.info(
            "Command failed with exit code: %s%s%s",
            p.returncode,
            stdout,
            stderr,
        )
        raise subprocess.CalledProcessError(p.returncode, cmd)

    return subprocess.CompletedProcess(
        p.args,
        p.returncode,
        p.stdout,
        p.stderr,
    )
