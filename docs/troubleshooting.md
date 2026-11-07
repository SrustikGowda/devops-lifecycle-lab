# Troubleshooting

Each item comes from what the scripts in this repo do.

## "Cannot connect to the Docker daemon" or `docker` commands hang

Docker Desktop is not running. Open it and wait until it says it is running. Then repeat the command. Needed for SonarQube, the scanner, image builds, and the local registry.

## SonarQube is not up yet

The first start takes about 1 to 2 minutes. `sonarqube/setup.sh` waits up to 60 checks of 5 seconds, then prints `SonarQube did not come up`. Check:

```bash
docker compose -f sonarqube/compose.yml ps
docker compose -f sonarqube/compose.yml logs --tail 30
curl -s http://localhost:9000/api/system/status
```

Expected when ready: JSON that contains `"status":"UP"`.

## setup.sh fails after you changed the admin password

`setup.sh` logs in as `admin:admin` unless told otherwise:

```bash
SONAR_ADMIN=admin:<your-password> bash sonarqube/setup.sh
```

## "SONAR_TOKEN" or "coverage.xml not found"

`scan.sh` needs both. Run `pytest` first, then `export SONAR_TOKEN=$(bash sonarqube/setup.sh)`.

## A port is busy (9000, 5001, 8081, 8082)

Find what uses it:

```bash
lsof -nP -iTCP:9000 -sTCP:LISTEN
```

Use the same command with 5001, 8081, or 8082. Stop that program, or the leftover container. `servers/up.sh` prints a WARNING if 8081 or 8082 is taken when it creates a VM. Note that 9000 is SonarQube and 5001 is the test registry (`docker rm -f lab-registry` stops it).

## The first `servers/up.sh` is very slow

It downloads Ubuntu once (about 7 minutes in our run). Let it finish. Later starts take about 20 seconds per VM. If a VM is stuck in a strange state, the script tells you what to try:

```bash
limactl stop -f lab-staging && bash servers/up.sh
```

Or start over with `bash servers/delete.sh`.

## "limactl not found"

```bash
brew install lima
```

## "Python 3.12 not found"

`runner/deploy.sh` looks for `python3.12`. On macOS:

```bash
brew install python@3.12
```

Make the venv with the same version: `python3.12 -m venv .venv`.

## The deploy says ROLLED BACK

The new container did not answer `/health` in about 30 seconds. Read the container logs Ansible printed just above. If you ran `break-it.sh port`, this is the expected result. Undo with `git checkout -- .`.

## DEPLOY FAILED ... no previous version

This was the server's first deploy, so there was nothing to roll back to. Fix the cause, deploy again.

## The server cannot pull the image from ghcr.io (GitHub path)

Not yet tested end to end. The servers pull without logging in, so the package must be public: Your profile, Packages, devops-lifecycle-lab, Package settings, Change visibility, Public. Also check the image name is all lowercase.

## The production job never starts (GitHub path)

It is waiting for your approval. Open the run page and press **Approve**. Make sure the environment is named exactly `production`.

## The deploy jobs stay "Queued" (GitHub path)

No runner with the label `lab` is online. Check **Settings, Actions, Runners** for status **Idle**, and that `./run.sh` is still running.

## You should see

When everything is healthy, `bash servers/status.sh` shows both servers `Running` with `OK (200)`, and `curl -s http://localhost:9000/api/system/status` contains `"status":"UP"`.

## The deploy jobs say "skipped"

That is on purpose until you turn them on: **Settings → Secrets and variables → Actions → Variables**, add `LAB_DEPLOY`
with the value `true`. Do it after the `staging` and `production` environments exist and your runner shows **Idle**.

## Linux: `servers/up.sh` fails to start a VM

Lima needs QEMU on Linux (macOS uses its built-in virtualization). Install it, for example on Ubuntu:
`sudo apt install qemu-system qemu-utils`, then run `bash servers/up.sh` again.
