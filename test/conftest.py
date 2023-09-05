import os
import random

import pytest
from moto.server import ThreadedMotoServer


@pytest.fixture(scope="session", autouse=True)
def moto_server():
    for i, port in enumerate(random.sample(range(50000, 50500), 100)):
        try:
            server = ThreadedMotoServer(port=port)
            server.start()
            os.environ["AWS_ENDPOINT_URL"] = f"http://localhost:{server._port}"
            yield server
            break
        except Exception:
            if i >= 10:
                raise
            raise
    server.stop()
