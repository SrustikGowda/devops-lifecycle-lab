# 07 Deploy

Deploy means: put the new image on a server and start it. We use **Ansible**, which describes the end state and makes it so.

## Files

| File | Job |
|---|---|
| `runner/deploy.sh` | Entry point. Sets up Ansible once, then runs the playbook. |
| `ansible/deploy.yml` | Checks the inputs, then runs the two roles. |
| `ansible/roles/docker/` | Installs Docker on the server (first deploy only does real work). |
| `ansible/roles/app/` | Replaces the `status-board` container and checks `/health`. |
| `ansible/inventory.ini` | `staging` = `lab-staging` (8081), `production` = `lab-prod` (8082). |

## What the `app` role does

1. Notes which image is running now.
2. Keeps a local copy of it (`status-board:rollback`).
3. Pulls the new image.
4. Starts the new container, mapping the server port to container port 8080.
5. Calls `/health` up to 15 times, 2 seconds apart (about 30 seconds).
6. If healthy: prints `DEPLOYED <version> to <server>`.
7. If not: prints the container's logs, starts the previous image again, and fails with `ROLLED BACK <server> to <previous image>`.

If it is the server's first ever deploy, there is nothing to go back to. You get `DEPLOY FAILED ...` and the broken container is removed.

Run it by hand:

```bash
bash runner/deploy.sh staging <image> <version>
```

## Environments and approval (GitHub path)

In `pipeline.yml` the `staging` job runs right after the image is pushed. The `production` job uses the `production` environment, which has **Required reviewers**. It waits until you press **Approve** on the run page. On the laptop path, `local-pipeline.sh` asks `Approve production? [y/N]` instead.

## See a rollback

```bash
bash scripts/break-it.sh port
YES=1 SKIP_SONAR=1 bash scripts/local-pipeline.sh
git checkout -- .
```

Tests pass (11), but the app now listens on 9090 and the health check on 8080 fails. The script stops at staging and production is never touched.

On GitHub the same mistake is stopped one step earlier: the CI job "Docker image builds and starts" runs the image and
asks `/health` on 8080, so the image is never pushed and nothing is deployed. That is what happened to our release 1.3.0.
Two layers, each with its own check: that's the point.

Timing: the first deploy to a fresh VM takes about 40 to 50 seconds (it installs Docker). Later ones take 3 to 14 seconds.

## You should see

Success:

```
msg: DEPLOYED 1.0.0 to lab-staging
```

Failure with `break-it.sh port`: the container logs, then

```
ROLLED BACK lab-staging to <previous image>
```

A few `FAILED - RETRYING: Wait for /health` lines before success are normal.

A full `YES=1 bash scripts/local-pipeline.sh` run took 85 seconds with SonarQube and 13 seconds with `SKIP_SONAR=1`, for a release.

## Our first real run on GitHub (7 Nov 2026)

Release 1.1.0, merged from a pull request: lint and tests 13 s, image smoke test 13 s, SonarQube gate 111 s, image
build and push for Intel and ARM 95 s, staging 110 s, then the run waited for **Approve**, and production took 81 s.
The first deploy on each server is the slowest (it sets up Ansible on the runner and Docker's settings on the server);
later ones take seconds.
