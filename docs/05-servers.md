# 05 Servers

A company deploys to servers. You get two on your laptop: **staging** (a practice place) and **production** (the real one). Each is a small Ubuntu 24.04 virtual machine (VM) made with **Lima**.

| VM | Role | App address on your laptop |
|---|---|---|
| `lab-staging` | staging | http://localhost:8081 |
| `lab-prod` | production | http://localhost:8082 |

Each VM has 2 CPUs, 2 GiB memory, and 10 GiB disk (`servers/lima/*.yaml`). Only the app port is forwarded to your laptop. The VMs have no shared folders.

## Commands

```bash
brew install lima
bash servers/up.sh        # create and start both (safe to run again)
bash servers/status.sh    # show state and health
bash servers/down.sh      # stop both, keep disks
bash servers/delete.sh    # delete both (asks first; -y skips the question)
```

The first `up.sh` took about 7 minutes (it downloads Ubuntu once). Later starts take about 20 seconds per VM.

The VMs start empty. Docker is installed on them by the first deploy ([07](07-deploy.md)).

## You should see

After `bash servers/up.sh`, the end of the output is a table:

```
SERVER       STATUS    APP                      APP HEALTH
lab-staging  Running   http://localhost:8081    no answer (nothing deployed yet?)
lab-prod     Running   http://localhost:8082    no answer (nothing deployed yet?)
```

After a deploy, the APP HEALTH column shows `OK (200)` for that server.
