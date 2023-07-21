# conftest.py - Pytest hooks and fixtures

"""Pytest hooks and fixtures."""

import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Generator, Optional

import boto3
import pytest
import tftest

from . import utils
from ._types import Image, Kubectl, KubernetesVersion, Platform
from .helm import Helm


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("aws_and_eks", "AWS and EKS")
    group.addoption(
        "--aws-skip-bringup",
        action="store_true",
        help="Do not bringup the AWS resources",
    )
    group.addoption(
        "--aws-skip-teardown",
        action="store_true",
        help="Do not teardown the AWS resources",
    )
    group.addoption(
        "--eks-kubernetes-version",
        type=KubernetesVersion,
        choices=list(KubernetesVersion),
        default=KubernetesVersion.latest(),
        help="Kubernetes control plane version",
    )

    group = parser.getgroup("xrd", "XRd")
    group.addoption(
        "--xrd-control-plane-repository",
        help="XRd Control Plane image repository",
    )
    group.addoption(
        "--xrd-control-plane-tags",
        nargs="+",
        default=["latest"],
        help="Space-separated list of XRd Control Plane image tags (default: "
        "'latest')",
    )
    group.addoption(
        "--xrd-vrouter-repository", help="XRd vRouter image repository"
    )
    group.addoption(
        "--xrd-vrouter-tags",
        nargs="+",
        default=["latest"],
        help="Space-separated list of XRd vRouter image tags (default: "
        "'latest')",
    )


def pytest_collection_modifyitems(
    config: pytest.Config, items: list[pytest.Item]
) -> None:
    new_items: list[pytest.Item] = []
    for item in items:
        if mark := item.get_closest_marker("platform"):
            if (
                mark.args[0] is Platform.XRD_CONTROL_PLANE
                and config.option.xrd_control_plane_repository is None
            ):
                item.add_marker(
                    pytest.mark.skip(
                        "Test is marked for platform xrd-control-plane but "
                        "`--xrd-control-plane-repository` was not provided"
                    )
                )
            elif (
                mark.args[0] is Platform.XRD_VROUTER
                and config.option.xrd_vrouter_repository is None
            ):
                item.add_marker(
                    pytest.mark.skip(
                        "Test is marked for platform xrd-vrouter but "
                        "`--xrd-vrouter-repository` was not provided"
                    )
                )

        # Make sure any items marked 'quickstart' are run first.
        if item.get_closest_marker("quickstart"):
            new_items.insert(0, item)
        else:
            new_items.append(item)

    items[:] = new_items


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """
    Generate parametrized calls to a test function.

    This is used to generate the dynamically parametrized ``image`` fixture.
    This fixture should yield a `_types.Image` for each tag specified in
    ``--xrd-control-plane-tags`` and ``--xrd-vrouter-tags`` respectively.  If
    the test is marked for a specific platform, then yield images for that
    particular platform only as appropriate.

    See https://docs.pytest.org/en/latest/how-to/parametrize.html#pytest-generate-tests
    for more details on this approach to parametrized fixtures.

    """
    if "image" in metafunc.fixturenames:
        images = []
        ids = []

        if mark := metafunc.definition.get_closest_marker("platform"):
            platforms = mark.args
        else:
            platforms = (Platform.XRD_CONTROL_PLANE, Platform.XRD_VROUTER)

        if (
            Platform.XRD_CONTROL_PLANE in platforms
            and metafunc.config.option.xrd_control_plane_repository
        ):
            for tag in metafunc.config.option.xrd_control_plane_tags:
                images.append(
                    Image(
                        Platform.XRD_CONTROL_PLANE,
                        metafunc.config.option.xrd_control_plane_repository,
                        tag,
                    ),
                )
                ids.append(f"{Platform.XRD_CONTROL_PLANE}:{tag}")

        if (
            Platform.XRD_VROUTER in platforms
            and metafunc.config.option.xrd_vrouter_repository
        ):
            for tag in metafunc.config.option.xrd_vrouter_tags:
                images.append(
                    Image(
                        Platform.XRD_VROUTER,
                        metafunc.config.option.xrd_vrouter_repository,
                        tag,
                    ),
                )
                ids.append(f"{Platform.XRD_VROUTER}:{tag}")

        if images:
            metafunc.parametrize(
                "image",
                argvalues=images,
                ids=ids,
            )


@pytest.fixture(scope="session")
def ami(
    request: pytest.FixtureRequest,
) -> Generator[Optional[str], None, None]:
    """
    Create and clean up an AMI using XRd Packer.

    """
    ami_id = None
    k8s_version = request.config.option.eks_kubernetes_version

    if not request.config.option.aws_skip_bringup:
        ami_id_re = re.compile(r"(ami-[0-9a-f]+)")

        try:
            utils.run_cmd(
                [
                    "git",
                    "clone",
                    "https://github.com/ios-xr/xrd-packer",
                    "xrd-packer",
                ]
            )

            utils.run_cmd(
                [
                    "packer",
                    "init",
                    "xrd-packer",
                ]
            )

            p = utils.run_cmd(
                [
                    "packer",
                    "build",
                    "-var",
                    f"kubernetes_version={str(k8s_version)}",
                    "-var",
                    'tags={"test": "xrd-terraform"}',
                    "xrd-packer/amazon-ebs.pkr.hcl",
                ],
                log_output=True,
            )

            ami_id_match = ami_id_re.search(p.stdout)
            if ami_id_match is not None:
                ami_id = ami_id_match.group()

        finally:
            shutil.rmtree("xrd-packer")

    yield ami_id

    if not request.config.option.aws_skip_teardown:
        # Delete all the images marked as test images for this version.
        ec2 = boto3.client("ec2")
        images_resp = ec2.describe_images(
            Filters=[
                {"Name": "tag:test", "Values": ["xrd-terraform"]},
                {
                    "Name": "tag:Kubernetes_Version",
                    "Values": [str(k8s_version)],
                },
            ]
        )

        images_to_delete = []
        snapshots_to_delete = []
        for i in images_resp["Images"]:
            images_to_delete.append(i["ImageId"])
            snapshots_to_delete.extend(
                [b["Ebs"]["SnapshotId"] for b in i["BlockDeviceMappings"]]
            )

        for image in images_to_delete:
            ec2.deregister_image(ImageId=image)

        for snapshot in snapshots_to_delete:
            ec2.delete_snapshot(SnapshotId=snapshot)


@pytest.fixture(scope="session")
def stack(
    request: pytest.FixtureRequest, ami: None
) -> Generator[None, None, None]:
    """
    Bring up and tear down the XRd Overlay example.

    """
    # Use the current directory for the data dir (for plugin downloads, etc.)
    # and the state files.
    cwd = Path.cwd()
    data_dir = cwd / ".terraform"
    os.environ["TF_DATA_DIR"] = str(data_dir)

    # Run the terraform stack to provision AWS resources.
    tf_vars = {}
    tf_vars["cluster_version"] = str(
        request.config.option.eks_kubernetes_version
    )

    this_dir = Path(__file__).resolve().parent

    tf_eks_cluster = tftest.TerraformTest(
        this_dir.parent / "examples" / "infra" / "eks-cluster"
    )
    tf_eks_bootstrap = tftest.TerraformTest(
        this_dir.parent / "examples" / "infra" / "eks-bootstrap"
    )
    tf_overlay = tftest.TerraformTest(
        this_dir.parent / "examples" / "workload" / "overlay"
    )

    tf_eks_cluster.setup()
    tf_eks_bootstrap.setup()
    tf_overlay.setup(extra_files=["overlay.tfvars"])

    try:
        if not request.config.option.aws_skip_bringup:
            tf_eks_cluster.apply(
                state=str(cwd / "terraform-eks-cluster.tfstate")
            )
            tf_eks_bootstrap.apply(
                state=str(cwd / "terraform-eks-bootstrap.tfstate")
            )
            tf_overlay.apply(
                state=str(cwd / "terraform-overlay.tfstate"),
                tf_vars=tf_vars,
                tf_var_file="overlay.tfvars",
            )

        # Ensure the Kubernetes config is updated.
        utils.run_cmd(
            [
                "aws",
                "eks",
                "update-kubeconfig",
                "--name",
                "xrd-cluster",
            ],
        )

        yield

    finally:
        if not request.config.option.aws_skip_teardown:
            tf_overlay.destroy(
                state=str(cwd / "terraform-overlay.tfstate"),
                tf_vars=tf_vars,
                tf_var_file="overlay.tfvars",
            )
            tf_eks_bootstrap.destroy(
                state=str(cwd / "terraform-eks-bootstrap.tfstate")
            )
            tf_eks_cluster.destroy(
                state=str(cwd / "terraform-eks-cluster.tfstate")
            )


@pytest.fixture(scope="session")
def kubectl(stack: None) -> Kubectl:
    """
    Fixture which provides a function to run a ``kubectl`` command, within the
    context of the XRd cluster.

    """

    def run_kubectl(*args, **kwargs) -> subprocess.CompletedProcess[str]:
        """
        Run a ``kubectl`` command.

        :param args:
            Arguments to pass to ``kubectl``.

        :param kwargs:
            Keyword arguments to pass to `utils.run_cmd`.

        :returns subprocess.CompletedProcess[str]:
            The completed ``kubectl`` process.

        """
        return utils.run_cmd(["kubectl", *args], **kwargs)

    return run_kubectl


@pytest.fixture(scope="session")
def helm(stack: None) -> Helm:
    """
    Fixture which provides an instance of the `Helm` wrapper, within the
    context of the XRd cluster.

    """
    helm = Helm()
    helm.repo_add(
        "xrd", "https://ios-xr.github.io/xrd-helm", force_update=True
    )
    return helm
