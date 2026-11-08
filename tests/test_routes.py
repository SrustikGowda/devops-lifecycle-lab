def test_board_page_lists_every_site(client, network_up):
    page = client.get("/").get_data(as_text=True)
    assert "Status Board" in page
    for domain in ("example.com", "example.org", "example.net"):
        assert domain in page
    assert page.count("ON TIME") == 3


def test_board_page_shows_problem_when_sites_are_down(client, network_down):
    assert client.get("/").get_data(as_text=True).count("PROBLEM") == 3


def test_page_header_shows_version_and_short_commit(client, network_up, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("GIT_SHA", "abcdef1234567890")
    page = client.get("/").get_data(as_text=True)
    assert "1.2.3" in page
    assert "abcdef1" in page
    assert "abcdef12" not in page


def test_health_says_ok_without_the_network(client):
    reply = client.get("/health")
    assert reply.status_code == 200
    assert reply.get_data(as_text=True) == "OK"
    assert reply.mimetype == "text/plain"


def test_version_reads_the_environment(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("GIT_SHA", "abcdef1234567890")
    monkeypatch.setattr("app.socket.gethostname", lambda: "status-board-7d9f-x2k4q")
    assert client.get("/version").get_json() == {
        "version": "1.2.3",
        "commit": "abcdef1234567890",
        "pod": "status-board-7d9f-x2k4q",
    }


def test_version_has_defaults_when_the_environment_is_empty(client, monkeypatch):
    monkeypatch.delenv("APP_VERSION", raising=False)
    monkeypatch.delenv("GIT_SHA", raising=False)
    reply = client.get("/version").get_json()
    assert (reply["version"], reply["commit"]) == ("dev", "local")
    assert reply["pod"]


def test_page_footer_shows_which_pod_answered(client, network_up, monkeypatch):
    monkeypatch.setattr("app.socket.gethostname", lambda: "status-board-7d9f-x2k4q")
    assert "served by status-board-7d9f-x2k4q" in client.get("/").get_data(as_text=True)
