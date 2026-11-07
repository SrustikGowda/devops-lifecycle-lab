# 06 Attach a runner

This page is only for path B (the GitHub path). Path A does not need it.

## Why

GitHub's machines run the tests and build the image. They cannot reach the VMs on your laptop, just as a cloud service cannot reach a company's private network. So the deploy jobs run on a **self-hosted runner**: a small program on your laptop that asks GitHub for work.

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Where | GitHub's cloud | Your laptop |
| Label in the workflow | `runs-on: ubuntu-latest` | `runs-on: [self-hosted, lab]` |
| Used by | `ci.yml`, job `release` | jobs `staging`, `production` |
| Can reach your VMs | No | Yes |

## The security rule

A self-hosted runner runs whatever the workflow says. On a public repo, a pull request from a stranger could say anything. So:

- Pull-request workflows (`ci.yml`) use only `ubuntu-latest`.
- Only `pipeline.yml` uses the `lab` runner, and only for commits on `main`.
- In your repo: **Settings, Actions, General, Fork pull request workflows, Require approval for all external contributors**.
- Never change a pull-request workflow to `self-hosted` on a public repo.

## Steps (about 3 minutes)

The full version is in [runner/README.md](../runner/README.md). In short:

1. In your repo: **Settings, Actions, Runners, New self-hosted runner**. Pick your OS and architecture.
2. Run the download commands GitHub shows, in a folder outside this repo (for example `~/actions-runner`).
3. Configure it with the label `lab`:
   ```bash
   ./config.sh --url https://github.com/<you>/devops-lifecycle-lab --token <TOKEN> --labels lab --name my-laptop --unattended
   ```
4. Start it:
   ```bash
   ./run.sh
   ```

The laptop also needs the VMs running (`bash servers/up.sh`), `python3.12`, and `curl`. `runner/deploy.sh` sets up Ansible by itself on the first run.

## Environments

**Settings, Environments**:

- `staging`: no rules.
- `production`: tick **Required reviewers** and add yourself.

## Remove the runner

```bash
./config.sh remove --token <TOKEN>
```

## You should see

On **Settings, Actions, Runners**, your runner `my-laptop` with the label `lab` and the status **Idle**. In the terminal where `./run.sh` is running, a line saying it is listening for jobs (the exact wording comes from GitHub's runner and may change).
