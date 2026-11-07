# Deploy with Ansible

Ansible logs in to each lab server (a Lima VM on your Mac), installs Docker the first time, and replaces the app
container. If the new version does not answer on `/health` within about 30 seconds, it puts the previous version back.

## Files

| File | What it is |
|---|---|
| `deploy.yml` | The playbook: checks the inputs, then runs the `docker` and `app` roles. |
| `inventory.ini` | The servers: group `staging` = `lab-staging` (port 8081), group `production` = `lab-prod` (port 8082). Ansible reaches them through the SSH config Lima writes (`~/.lima/<name>/ssh.config`). No passwords or keys in here. |
| `roles/docker/` | Installs Docker Engine (Ubuntu's `docker.io`) and writes `/etc/docker/daemon.json`. |
| `roles/app/` | Records the running image, pulls the new one, replaces the `status-board` container, waits for `/health`, rolls back on failure. |
| `ansible.cfg` | Settings: inventory, collections inside the repo, YAML output. Host keys are checked against the file Lima keeps for each VM (`~/.lima/<name>/ssh.known_hosts`). |
| `requirements-deploy.txt` | The pinned Ansible version (Python package). |
| `requirements.yml` | The pinned `community.docker` collection. |

## One-time setup (from the repo root)

Needs Docker Desktop running and `brew install lima python@3.12`.

```bash
/opt/homebrew/bin/python3.12 -m venv ansible/.venv
source ansible/.venv/bin/activate
pip install -r ansible/requirements-deploy.txt
ansible-galaxy collection install -r ansible/requirements.yml -p ansible/collections
export ANSIBLE_CONFIG=ansible/ansible.cfg      # use this folder's settings from the repo root
bash servers/up.sh                             # creates lab-staging and lab-prod
```

In a new terminal, run the `source` and `export` lines again.

## Deploy

```bash
ansible-playbook -i ansible/inventory.ini ansible/deploy.yml -l staging \
  -e app_image=ghcr.io/<owner>/devops-lifecycle-lab:<commit sha> -e app_version=<text>
```

Use `-l production` for production. A few `FAILED - RETRYING: Wait for /health` lines are normal while the new
container starts. What you should see at the end:

- Success: `msg: DEPLOYED <version> to lab-staging`, and http://localhost:8081 shows the app (8082 for production).
- Unhealthy new version: the new container's logs, then `msg: ROLLED BACK lab-staging to <previous image>`, and the
  command fails (exit code 2). The previous version keeps serving. (On a server's very first deploy there is nothing
  to go back to: you get `DEPLOY FAILED ...` and the broken container is removed.)

Running the same deploy twice changes nothing the second time: the container is only replaced when the image or
version changes.

The servers pull from ghcr.io without logging in, so make the image package public on GitHub
(Package settings, Change visibility). Image names must be lowercase.

## Test it locally, without GitHub

A throwaway registry on your Mac and a tiny stub image (`good` listens on 8080, `bad` on the wrong port):

```bash
bash servers/dev-registry.sh                 # registry:2 on localhost:5001 (container lab-registry)
bash servers/dev/stub/build-and-push.sh      # pushes lab-stub:good and lab-stub:bad

ansible-playbook -i ansible/inventory.ini ansible/deploy.yml -l staging \
  -e app_image=host.lima.internal:5001/lab-stub:good -e app_version=stub-good \
  -e '{"insecure_registries": ["host.lima.internal:5001"]}'
curl -i http://localhost:8081/health          # HTTP/1.0 200 OK
```

`host.lima.internal` is how a VM reaches your Mac. `insecure_registries` lets Docker on the VM pull from that registry
over plain HTTP. It exists only for this local test; the real pipeline pulls from ghcr.io over HTTPS and leaves it empty
(running a deploy without it removes the setting again). Changing it restarts Docker on the VM, so the app is down
for a few seconds that one time.
