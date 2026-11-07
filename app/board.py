"""Status logic as plain functions, so it can be unit tested without the network."""

import time
from concurrent.futures import ThreadPoolExecutor
from urllib.request import Request, urlopen

# Reserved documentation domains: always safe to call, owned by IANA.
SITES = ("https://example.com", "https://example.org", "https://example.net")

TIMEOUT_SECONDS = 2  # give up on a site after this long
SLOW_SECONDS = 1.0  # answered, but slower than this means DELAYED

# Some sites refuse Python's default User-Agent, so say who we are.
HEADERS = {"User-Agent": "status-board/1.0 (teaching demo)"}

ON_TIME = "ON TIME"
DELAYED = "DELAYED"
PROBLEM = "PROBLEM"


def status_label(ok, elapsed):
    """Turn "did it answer well" and "how long it took" into one label."""
    if not ok:
        return PROBLEM
    if elapsed > SLOW_SECONDS:
        return DELAYED
    return ON_TIME


def check_site(url):
    """Call one site and return its label. Any failure counts as a PROBLEM."""
    started = time.monotonic()
    try:
        with urlopen(Request(url, headers=HEADERS), timeout=TIMEOUT_SECONDS) as reply:
            ok = 200 <= reply.status < 400
    except Exception:
        ok = False
    return status_label(ok, time.monotonic() - started)


def check_all(sites=SITES):
    """Check every site at the same time and return a list of {url, status}."""
    with ThreadPoolExecutor(max_workers=len(sites)) as pool:
        labels = pool.map(check_site, sites)
    return [{"url": url, "status": label} for url, label in zip(sites, labels, strict=True)]

