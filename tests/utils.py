__all__ = ("run_cmd",)

import logging
import shlex
import subprocess

logger = logging.getLogger(__name__)


def run_cmd(
    cmd: list[str],
    *,
    log_output: bool = True,
    **kwargs,
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
        kwargs,
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
