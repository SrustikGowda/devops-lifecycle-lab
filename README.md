# DevOps Lifecycle Lab

This repo ships a tiny web app (the Status Board) the way real companies do: tests, a quality gate, a Docker image, and a deploy to staging and production, with automatic rollback. You run the whole thing on your own laptop, for free.

## Which episode do you want?

| Episode | Deploys to | Where to find it | Start here |
|---|---|---|---|
| 4 | Two Lima VMs, with Ansible | `git checkout ep4-ansible` (release 1.4.2) | The sections below |
| 5 | A Kubernetes cluster (kind), with kubectl | `main` | [Episode 5: Kubernetes](#episode-5-kubernetes) and [docs/09-kubernetes.md](docs/09-kubernetes.md) |

The sections below and pages 05 to 08 still describe the episode-4 version (Lima and Ansible, which are still in `main`). Pages 09 and 10 cover Kubernetes.

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

## Episode 5: Kubernetes

Staging and production now run on a small Kubernetes cluster on your laptop, made by kind. The pipeline deploys with `bash runner/deploy-k8s.sh` instead of Ansible, and its smoke test checks the version.

You need: Docker (running), `kind` and `kubectl` (`brew install kind kubectl`). Memory: the cluster uses about 1.7 GB with both environments running (we measured about 820 MiB for the control plane and 430 MiB for each worker). Give Docker at least 4 GB.

Check where kubectl points, so you know where your own commands go. The scripts in this repo always use the context `kind-lab`.

```bash
kubectl config current-context
```

Laptop only:

```bash
bash servers/down.sh        # only if episode 4's servers are running: they use ports 8081 and 8082
bash scripts/k8s-up.sh      # creates the cluster, builds the image, deploys staging and production
bash scripts/k8s-traffic.sh 8081   # optional: five requests a second, with a running count
bash scripts/k8s-down.sh    # remove everything
```

You should see: `k8s-up.sh` ends with `DEPLOYED <version> to production`, then the two addresses. http://localhost:8081 (staging) and http://localhost:8082 (production) show the Status Board. The footer says "served by" and a pod name. `/version` also returns the pod name.

GitHub path: the same steps as B below, but the runner needs the kind cluster, `kubectl` and the context `kind-lab` instead of the Lima servers ([docs/06-attach-a-runner.md](docs/06-attach-a-runner.md)). `LAB_DEPLOY` and the production approval work as before.

Break it on purpose, then find the cause with `get pods`, `describe pod` and `logs` ([docs/10-diagnose.md](docs/10-diagnose.md)):

```bash
bash scripts/break-it.sh k8s-port     # wrong port in the Kubernetes file: CI passes, the new pod never becomes ready
bash scripts/break-it.sh k8s-memory   # memory limit too small: the new pods are OOMKilled
bash scripts/k8s-freeze.sh staging    # one pod stops answering: Kubernetes takes it out, then restarts it
```

Undo the first two with `git checkout -- .` and `kubectl --context kind-lab -n staging rollout undo deployment/status-board`.

## Break it on purpose

```bash
bash scripts/break-it.sh test       # a bug: the unit tests fail
bash scripts/break-it.sh coverage   # untested code: tests pass, the quality gate fails
bash scripts/break-it.sh port       # wrong port: tests pass; on GitHub the image smoke test stops it,
                                    # on the laptop path staging's health check fails and the deploy rolls back
```

Undo any of them with `git checkout -- .`

## Costs

Free for a public repo: GitHub Actions minutes, ghcr.io, SonarQube Community Build, Lima, kind and kubectl. Docker Desktop is free for personal use, education and small businesses; at a larger company use Colima or Rancher Desktop, both free.

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
| [09 Kubernetes](docs/09-kubernetes.md) | Deployment, Service, probes, rolling update |
| [10 Diagnose](docs/10-diagnose.md) | `get pods`, `describe pod`, `logs`, and three exercises |
| [Jenkins vs Actions](docs/jenkins-vs-actions.md) | For Jenkins users |
| [Troubleshooting](docs/troubleshooting.md) | When something breaks |

Made for the Tech with Srustik YouTube channel: https://www.youtube.com/@TechWithSrustik
