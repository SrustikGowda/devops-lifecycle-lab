# 04 Package

The pipeline puts the app in a **Docker image**: the code, Python, and its libraries in one file that runs the same everywhere.

## The Dockerfile

`Dockerfile` has two stages. The first installs the libraries. The second copies only what the app needs, runs as a non-root user, and starts `gunicorn` on port 8080. It has a `HEALTHCHECK` that calls `/health`.

Build arguments set the version and commit inside the image:

```bash
docker build --build-arg APP_VERSION="$(cat VERSION)" --build-arg GIT_SHA=local -t status-board:test .
docker run -d --name try -p 8080:8080 status-board:test
curl http://localhost:8080/version
docker rm -f try
```

## Tags: the commit SHA

In `pipeline.yml` the image gets two tags:

- `ghcr.io/<you>/devops-lifecycle-lab:<full commit SHA>`: unique, never moves. This is what gets deployed.
- `ghcr.io/<you>/devops-lifecycle-lab:main`: moves with every release. Easy to remember, not safe to deploy by.

With the SHA, you always know which code is running, and you can go back to any earlier build.

## ghcr.io

`ghcr.io` is GitHub's container registry. The workflow logs in with the built-in `GITHUB_TOKEN`, so you create no secret. Registry names must be lowercase; the workflow lowercases your repo name.

**Note (not yet tested end to end):** if the servers cannot pull the image, make the package public: Your profile, Packages, devops-lifecycle-lab, Package settings, Change visibility, Public. The servers pull without logging in.

## Multi-arch

The workflow builds for `linux/amd64` (Intel and AMD servers) and `linux/arm64` (Apple silicon VMs, Raspberry Pi, many cloud ARM servers). One tag covers both. Docker picks the right one on pull. Your Lima VMs on an M-series Mac use arm64.

## On your laptop

`scripts/local-pipeline.sh` pushes to a local registry instead (`bash servers/dev-registry.sh`, port 5001). The tag is the commit SHA, or `<short sha>-dirty` if you have uncommitted changes.

## You should see

`curl http://localhost:8080/version` prints:

```
{"commit":"local","version":"1.0.0"}
```

In GitHub, after a pipeline run, your profile's **Packages** tab lists `devops-lifecycle-lab` with the SHA tag and `main`.
