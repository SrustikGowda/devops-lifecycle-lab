# 08 Watch

Shipping is not the end. You must know if the app is alive.

## /health

`GET /health` returns `200` and the text `OK`. It never calls the network. It only says "the process is up". Three things use it:

- The Dockerfile `HEALTHCHECK` (every 5 seconds).
- Ansible, after each deploy, to decide between `DEPLOYED` and `ROLLED BACK`.
- `bash servers/status.sh`.

```bash
curl -i http://localhost:8081/health
```

## /version

`GET /version` returns the version and the commit the container was built from:

```bash
curl http://localhost:8081/version
```

When a bug is reported, this tells you which code is running. Compare the commit with your git history.

## Logs

```bash
limactl shell lab-staging sudo docker logs --tail 20 status-board
```

## What to monitor next

`/health` says the app is up, not that users are happy. Real teams also watch:

- Error rate: how many requests fail.
- Latency: how long requests take.
- Traffic and saturation: how busy the server is.

Turn these into targets called SLOs (service level objectives) and alert when you burn through them. Starter for the next episode: https://github.com/SrustikGowda/status-board-starter/tree/main/slo

## You should see

A status line with `200 OK`, then headers, then the body `OK`. For `/version`, a JSON line such as:

```
{"commit":"<40-character commit sha>","version":"1.0.0"}
```

The version is the content of the `VERSION` file at build time. The main page also shows it.
