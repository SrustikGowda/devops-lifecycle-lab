from app.board import DELAYED, ON_TIME, PROBLEM, SITES, check_all, check_site, status_label


def test_fast_answer_is_on_time():
    assert status_label(ok=True, elapsed=0.2) == ON_TIME


def test_slow_answer_is_delayed():
    assert status_label(ok=True, elapsed=1.5) == DELAYED


def test_failed_answer_is_a_problem_even_when_fast():
    assert status_label(ok=False, elapsed=0.1) == PROBLEM


def test_check_site_reports_problem_when_the_network_fails(network_down):
    assert check_site("https://example.com") == PROBLEM


def test_check_all_returns_one_row_per_site(network_up):
    rows = check_all()
    assert [row["url"] for row in rows] == list(SITES)
    assert {row["status"] for row in rows} == {ON_TIME}
