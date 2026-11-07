# 00 The lifecycle

Every piece of software goes through the same eight steps. DevOps means one team owns all of them and automates the boring parts, so a change can reach users quickly and safely.

| Step | What happens | Where in this repo |
|---|---|---|
| Plan | Decide what to change. Write it down as an issue. | GitHub Issues ([01](01-plan-and-code.md)) |
| Code | Write the change on a branch. Open a pull request. | `app/`, `tests/` |
| Build | Turn the code into something you can run: a Docker image. | `Dockerfile`, `pipeline.yml` job `release` ([04](04-package.md)) |
| Test | Run automatic checks. | `ci.yml` job `test`, `pyproject.toml` ([02](02-test.md)) |
| Release | Give this exact build a name: the commit SHA. | `ghcr.io/<you>/devops-lifecycle-lab:<sha>` |
| Deploy | Put the build on a server. Staging first, then production. | `ansible/`, `runner/deploy.sh` ([07](07-deploy.md)) |
| Operate | Keep it running. Roll back if the new version is sick. | `ansible/roles/app/` |
| Monitor | Ask the app if it is healthy. | `/health`, `/version` ([08](08-watch.md)) |

The quality gate sits between Test and Release. It reads the test coverage report and blocks the release if coverage is too low ([03](03-quality-gate.md)).

## Where DevOps fits

Before DevOps, developers wrote code and handed it to a separate team to run. Handoffs were slow and blamed people. In DevOps, one pipeline does the same steps every time. People review and approve. Machines repeat.

In this repo the pipeline is two files: `.github/workflows/ci.yml` (checks) and `.github/workflows/pipeline.yml` (release and deploy). For the same thing on a laptop, read `scripts/local-pipeline.sh`.

## You should see

Open `.github/workflows/pipeline.yml`. The jobs appear in this order: `checks`, `release`, `staging`, `production`. Each one starts only after the one before it succeeds.
