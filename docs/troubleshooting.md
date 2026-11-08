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

The servers download the image without logging in, so the package must be public. A public repo's package is normally public already. If not: Your profile, Packages, devops-lifecycle-lab, Package settings, Change visibility, Public. Then run the deploy again.

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

## The board on staging or production says DELAYED or PROBLEM, but the sites are fine

The servers are slow to look up names. On a Mac, Lima's built-in DNS answers IPv6 lookups slowly and its network can
drop one of two lookups sent at the same moment, so every check waited 2 to 5 seconds. The deploy now gives the app's
containers public DNS (1.1.1.1 and 8.8.8.8) and makes them ask one question at a time
(`ansible/roles/docker/defaults/main.yml`). Deploy again and the board should say ON TIME.

If your network blocks public DNS, set `docker_dns: []` in that file to use the server's own DNS. If you switched
networks or a VPN on or off after the servers started, also restart them:

```bash
bash servers/down.sh && bash servers/up.sh
```

## Kubernetes (episode 5)

These items are for the Kubernetes version.

### Port 8081 or 8082 is already in use

Episode 4's Lima servers use the same two ports. Stop them, then try again:

```bash
bash servers/down.sh
bash scripts/k8s-up.sh
```

`k8s-up.sh` checks both ports before it creates the cluster and tells you which one is busy. To see what holds a port, use the `lsof` command from "A port is busy" above.

### kubectl talks to the wrong cluster

kubectl sends every command to the current context in `~/.kube/config`. Check it:

```bash
kubectl config current-context
```

The scripts in this repo always use `kind-lab`, so they are safe. Your own commands are not, unless you add `--context kind-lab`. The lab cluster's context is created by kind.

### ImagePullBackOff (GitHub path)

The pod could not download the image from ghcr.io. The package must be public, because the cluster does not log in. Make it public as in [04](04-package.md): your profile, Packages, devops-lifecycle-lab, Package settings, Change visibility, Public. Then deploy again. To see the exact error:

```bash
kubectl --context kind-lab -n staging describe pod <name>
```

### `kind load` fails with "content digest not found"

Some Docker setups add extra data (provenance) to the images they build, and `kind load` may fail to copy it. Build without it, with `--provenance=false`. `scripts/k8s-up.sh` already does this, so you should only meet this error if you build the image by hand.

### CreateContainerConfigError about runAsNonRoot

The message says the container has `runAsNonRoot` and an image user it cannot verify. The Dockerfile's user is a name (`appuser`). Kubernetes can only check a number. The Deployment sets `runAsUser: 10001` (the user's ID) for this reason. If you removed that line from `k8s/base/deployment.yaml` or from a demo pod, put it back.

### A pod is "forbidden: violates PodSecurity "restricted""

Both namespaces only accept pods that can't get root on the node (the label `pod-security.kubernetes.io/enforce:
restricted` in `k8s/overlays/*/namespace.yaml`). The Deployment and the two demo pods already follow the rules. If you
changed a `securityContext` (for example removed `runAsNonRoot`, `allowPrivilegeEscalation: false` or `drop: ["ALL"]`),
put it back. The error message names the exact rule.

### The cluster stops answering ("TLS handshake timeout")

kind's nodes share Docker with everything else you run. If other containers keep Docker busy, or it runs short of
memory, the cluster's API can stop answering. Stop the other containers, or give Docker more memory, and wait a minute.
If it still doesn't answer, make a fresh cluster: `bash scripts/k8s-down.sh && bash scripts/k8s-up.sh`.

### The runner cannot find kubectl (GitHub path)

The runner may start with a short PATH. `runner/deploy-k8s.sh` looks for kubectl in PATH, `/opt/homebrew/bin`, `/usr/local/bin` and `~/.docker/bin`. If yours is somewhere else, set `KUBECTL` to its full path in the environment of the runner. If it says `No kubectl context "kind-lab"`, the cluster does not exist yet: run `bash scripts/k8s-up.sh`, or `kind create cluster --config k8s/kind-config.yaml`.

### The rollout is stuck

The deploy script printed `ROLLOUT STUCK`. The old pods are still serving. Read [10 Diagnose](10-diagnose.md), find the cause, then undo:

```bash
kubectl --context kind-lab -n staging rollout undo deployment/status-board
```

### The Service has no endpoints

All pods are `Running`, but the address does not answer. Either no pod is ready, or the Service's `selector` does not match the pods' labels. See "Another case" in [10 Diagnose](10-diagnose.md).
