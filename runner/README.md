# Attach your laptop as a runner (the Jenkins "agent" idea)

GitHub's own machines run the checks and build the image. They can't reach the Kubernetes cluster on your laptop, the same way a
cloud service can't reach a company's private network. So the deploy jobs run on a machine *inside* that network: a
**self-hosted runner**. In Jenkins words, GitHub is the controller and this runner is an agent (a "node").

## Before you attach it: one security rule

A self-hosted runner runs whatever a workflow tells it to. On a public repo, that could be code from a stranger's pull
request. This repo is set up so that can't happen:

- `ci.yml` (what pull requests run) only uses `runs-on: ubuntu-latest`, GitHub's machines.
- Only `pipeline.yml` uses `runs-on: [self-hosted, lab]`, and its deploy jobs only run for `main`, and only after you
  set the repository variable `LAB_DEPLOY` to `true` (see "Turn deploys on" below).
- In your repo, also turn on: **Settings → Actions → General → Fork pull request workflows → Require approval for all
  external contributors**.

Never change a pull-request workflow to `self-hosted` on a public repo.

## Attach it (about 3 minutes)

1. In your repo: **Settings → Actions → Runners → New self-hosted runner**, pick your OS and architecture.
2. Run the download commands GitHub shows you, in a folder outside this repo, e.g. `~/actions-runner`.
3. Configure it with the label `lab` (the token on that page is valid for one hour):
   ```
   ./config.sh --url https://github.com/<you>/devops-lifecycle-lab --token <TOKEN> --labels lab --name my-laptop --unattended
   ```
4. Start it: `./run.sh`. Back on the Runners page it shows **Idle**: it's attached and waiting for work.

The runner needs (episode 5; the deploy jobs run `bash runner/deploy-k8s.sh`):
- The kind cluster running: `bash scripts/k8s-up.sh`, or `kind create cluster --config k8s/kind-config.yaml`.
- `kubectl`. The script looks in `PATH`, `/opt/homebrew/bin`, `/usr/local/bin` and `~/.docker/bin`.
- `~/.kube/config` with the context `kind-lab`. kind writes it. Run the runner as the user who created the cluster.
- `curl`, for the smoke test after each deploy.

The Lima servers, `python3.12` and Ansible (`runner/deploy.sh`) are only needed for the episode-4 version
(`git checkout ep4-ansible`).

## Environments (the approval button)

Do this before you turn deploys on. In your repo: **Settings → Environments**:
- `staging`: no reviewers. Deploys right after the image is pushed.
- `production`: tick **Required reviewers** and add yourself. The production job waits until you press **Approve**.
- On both, set **Deployment branches and tags** to the `main` branch only.

Required reviewers need a **public** repo on GitHub's free plan. If you make your copy private, production would deploy
without asking.

## Turn deploys on

**Settings → Secrets and variables → Actions → Variables → New repository variable**: name `LAB_DEPLOY`, value `true`.
Until then the Pipeline still tests and builds, and skips the two deploy jobs.

## Remove it

`./config.sh remove --token <TOKEN>` (Settings → Actions → Runners → the runner → Remove shows the token).
