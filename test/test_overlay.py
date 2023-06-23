# test_overlay.py

"""End-to-end tests for the Overlay application."""


import subprocess

import pytest

from . import utils
from ._types import Kubectl, Platform
from .helm import Helm


pytestmark = pytest.mark.platform(Platform.XRD_VROUTER)


def check_bgp_established(
    kubectl: Kubectl,
    pod_name: str,
    neighbor: str,
) -> bool:
    """
    Check whether a BGP session is established with the given neighbor.

    :param kubectl:
        Kubectl context.

    :param pod_name:
        Pod from which to check BGP connectivity.

    :param neighbor:
        IP address of the neighbor.

    :return:
        True if the connection is established.
        False otherwise.

    """
    try:
        p = kubectl(
            "exec",
            pod_name,
            "--",
            "xrenv",
            "bgp_show",
            "-V",
            "default",
            "-n",
            "-br",
            "-instance",
            "default",
            log_output=True,
        )
    except subprocess.CalledProcessError:
        return False

    # Example output:
    #
    # Neighbor        Spk    AS Description                          Up/Down  NBRState
    # 10.1.0.2          0     1                                      00:17:12 Established
    # 100.0.0.1         0     1                                      00:15:44 Established
    #
    # Grab the fifth column of the correct neighbour.
    for line in p.stdout.strip().splitlines():
        cols = line.split()
        if cols[0] == neighbor:
            if cols[4] == "Established":
                return True
            break

    return False


@pytest.mark.quickstart
def test_quickstart(kubectl: Kubectl, helm: Helm) -> None:
    """XRd QuickStart should install the example Overlay application."""
    expected_release_names = {"xrd1", "xrd2"}

    releases = helm.list()

    assert len(releases) == len(expected_release_names)
    release_names = set(r.name for r in releases)
    assert release_names == expected_release_names

    # Wait for the pods to come up.
    # Wait for the first pod for 5 minutes - most of the wait will be
    # image pull time so give quite a generous timeout.
    # The second pod should be ready at the same time as the first pod, so
    # just use the default timeout of 30 seconds.
    kubectl("wait", "--for=condition=Ready", "pod/xrd1-xrd-vrouter-0", "--timeout=5m")
    kubectl("wait", "--for=condition=Ready", "pod/xrd2-xrd-vrouter-0")

    # After booting can take a couple of minutes to establish a BGP
    # connection. Normally this happens in <60seconds, but extend the timeout
    # of the first check to five minutes to handle uncommonly slow start-ups.
    # Further checks can use a much shorter timeout.
    if not utils.wait_until(
        5,
        300,
        check_bgp_established,
        kubectl,
        f"xrd1-xrd-vrouter-0",
        "1.0.0.12",
    ):
        assert False, f"BGP not established"

    if not utils.wait_until(
        5,
        60,
        check_bgp_established,
        kubectl,
        f"xrd2-xrd-vrouter-0",
        "1.0.0.11",
    ):
        assert False, f"BGP not established"

    for address in ("10.0.2.12", "10.0.3.12"):
        if not utils.wait_until(
            5,
            60,
            utils.check_ping,
            kubectl,
            f"xrd1-xrd-vrouter-0",
            address,
        ):
            assert (
                False
            ), f"Could not ping {address} from xrd1-xrd-vrouter-0"

    for address in ("10.0.2.11", "10.0.3.11"):
        if not utils.wait_until(
            5,
            60,
            utils.check_ping,
            kubectl,
            f"xrd2-xrd-vrouter-0",
            address,
        ):
            assert (
                False
            ), f"Could not ping {address} from xrd2-xrd-vrouter-0"
