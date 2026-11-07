# DevOps Lifecycle Lab

This repo ships a tiny web app (the Status Board) the way real companies do: tests, a quality gate, a Docker image, and a deploy to staging and production, with automatic rollback. You run the whole thing on your own laptop, for free.

## The 8 stages

```
Plan -> Code -> Test -> Check -> Package -> Attach -> Deploy -> Watch
 |       |       |       |        |          |         |         |
Issue   Git    pytest  Sonar-   Docker    Runner    Ansible   /health
        +      +       Qube     image     on your   + GitHub  /version
        PR     ruff    gate     (ghcr.io) laptop    environ-
                                                    ments
```

## Two ways to run it

### A) Everything on your laptop (start here)

No GitHub account needed. One script does every stage in order.

You need: Docker Desktop (running), Homebrew, `python@3.12`, and `lima`.

```bash
brew install python@3.12 lima
python3.12 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
docker compose -f sonarqube/compose.yml up -d
bash servers/up.sh
bash servers/dev-registry.sh
bash scripts/local-pipeline.sh
```

Wait about 2 minutes after the SonarQube command before the last one. The first `servers/up.sh` takes several minutes because it downloads Ubuntu once.

You should see: each step prints a heading (`== 1/6 Lint ==` up to `== 6/6 Deploy to production ==`). It asks `Approve production? [y/N]`. Type `y`. The last line is the JSON from the production app, for example `{"commit":"...","version":"1.0.0"}`. Open http://localhost:8081 (staging) and http://localhost:8082 (production).

Details: [docs/05-servers.md](docs/05-servers.md) and [docs/03-quality-gate.md](docs/03-quality-gate.md).

### B) The real thing on GitHub

1. Press **Use this template → Create a new repository**. Keep it **public** (the approval button on the free plan needs a
   public repo). Don't fork: a fork's pull requests would go to this repo, not yours.
2. Your new repo runs the Pipeline once straight away. It tests the code and pushes the image to ghcr.io, and the deploy
   jobs are skipped: they stay off until step 6.
3. Check the image is public: your profile, **Packages**, `devops-lifecycle-lab`. A public repo's package is normally
   public already; if it says Private, open **Package settings → Change visibility → Public**. Your servers download it
   without a password.
4. Create two environments (**Settings → Environments**): `staging` with no rules, and `production` with
   **Required reviewers** (add yourself). On both, set **Deployment branches** to `main` only.
5. Run `bash servers/up.sh`, then attach your laptop as a runner with the label `lab`:
   [docs/06-attach-a-runner.md](docs/06-attach-a-runner.md).
6. Turn deploys on: **Settings → Secrets and variables → Actions → Variables → New repository variable**,
   name `LAB_DEPLOY`, value `true`.
7. Merge a pull request into `main`. Watch the **Actions** tab. Press **Approve** when production waits.

If something fails, see [docs/troubleshooting.md](docs/troubleshooting.md).

## Break it on purpose

```bash
bash scripts/break-it.sh test       # a bug: the unit tests fail
bash scripts/break-it.sh coverage   # untested code: tests pass, the quality gate fails
bash scripts/break-it.sh port       # wrong port: tests pass; on GitHub the image smoke test stops it,
                                    # on the laptop path staging's health check fails and the deploy rolls back
```

Undo any of them with `git checkout -- .`

## Costs

Free for a public repo: GitHub Actions minutes, ghcr.io, SonarQube Community Build, and Lima. Check Docker Desktop's license terms for your own use.

## Security rule for self-hosted runners

- Never run pull-request workflows on your own runner in a public repo. A stranger could run code on your laptop.
- Only `pipeline.yml` uses the `lab` runner, and only for commits on `main`, after you set `LAB_DEPLOY`.
- In your repo, set **Settings → Actions → General → Fork pull request workflows** to
  **Require approval for all external contributors**.

## Read next

| Page | Topic |
|---|---|
| [00 The lifecycle](docs/00-the-lifecycle.md) | The big picture |
| [01 Plan and code](docs/01-plan-and-code.md) | Issue, branch, pull request |
| [02 Test](docs/02-test.md) | pytest, coverage, ruff |
| [03 Quality gate](docs/03-quality-gate.md) | SonarQube |
| [04 Package](docs/04-package.md) | Docker image and registry |
| [05 Servers](docs/05-servers.md) | Two Lima VMs |
| [06 Attach a runner](docs/06-attach-a-runner.md) | Your laptop as a runner |
| [07 Deploy](docs/07-deploy.md) | Ansible, rollback, approval |
| [08 Watch](docs/08-watch.md) | Health checks and what is next |
| [Jenkins vs Actions](docs/jenkins-vs-actions.md) | For Jenkins users |
| [Troubleshooting](docs/troubleshooting.md) | When something breaks |

Made for the Tech with Srustik YouTube channel: https://www.youtube.com/@TechWithSrustik
