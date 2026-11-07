from urllib.error import URLError

import pytest

from app import create_app


class FakeReply:
    """Stands in for the object urlopen returns, so no test touches the network."""

    def __init__(self, status=200):
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        return False


@pytest.fixture
def client():
    return create_app().test_client()


@pytest.fixture
def network_up(monkeypatch):
    monkeypatch.setattr("app.board.urlopen", lambda url, timeout: FakeReply(200))


@pytest.fixture
def network_down(monkeypatch):
    def refuse(url, timeout):
        raise URLError("no network in tests")

    monkeypatch.setattr("app.board.urlopen", refuse)
