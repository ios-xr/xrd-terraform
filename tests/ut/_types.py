__all__ = (
    "MotoServer",
    "TerraformOutputs",
)

import json
from functools import partial
from typing import Any, Mapping

import cattrs
import requests
from attrs import define, fields
from cattrs.errors import ForbiddenExtraKeysError
from moto.server import ThreadedMotoServer


class TerraformOutputs:
    """
    Represents Terraform outputs.

    Example usage::

        @attrs.define
        class Outputs(TerraformOutputs):
            foo: str
            bar: str

        outputs = Outputs.from_terraform(tf)
        print(outputs.foo)
        print(outputs.bar)

    This class provides the `from_terraform` helper to parse the output of
    ``terraform output`.

    """

    @staticmethod
    def structure(
        c,
        d: Mapping[str, Any],
        t: "TerraformOutputs",
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
            cls,
            partial(cls.structure, converter),
        )
        return converter.structure(d, cls)


@define
class MotoServer:
    """Wrapper around `ThreadedMotoServer`."""

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
