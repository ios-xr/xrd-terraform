__all__ = ("MotoServer",)


import requests
from attrs import define
from moto.server import ThreadedMotoServer


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
