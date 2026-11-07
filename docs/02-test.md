# 02 Test

Two tools check the code before anything else happens.

- **ruff** reads the code and finds style mistakes and likely bugs. It does not run the code.
- **pytest** runs the unit tests in `tests/` and measures **coverage**: the share of code lines the tests ran.

Settings for both are in `pyproject.toml`.

## Run them

Set up once (Python 3.12 needed):

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

Then:

```bash
ruff check .
pytest
```

Plain `pytest` also writes `coverage.xml` at the repo root. SonarQube reads that file ([03](03-quality-gate.md)).

## Tests never use the network

The app checks three websites. The tests replace those calls with fake ones, so they run the same on every machine, offline.

## Why the CI job runs inside a Docker container

In `ci.yml` the `test` job has `container: python:3.12-slim`. Every run starts from the same clean Python 3.12 image. Nothing is left over from an earlier run, and the Python version does not change when GitHub updates its machines. "Works on my machine" becomes "works in this image".

## Break a test on purpose

```bash
bash scripts/break-it.sh test
pytest
git checkout -- .
```

## You should see

On a clean checkout (7 Nov 2026, macOS):

```
ruff check .
All checks passed!
```

`pytest` ends with 11 tests passed and coverage 100% (46 statements).

After `break-it.sh test`, `pytest` reports failing tests and exits with a non-zero code. After `git checkout -- .` it passes again.
