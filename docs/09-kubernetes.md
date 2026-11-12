# 09 Kubernetes

In episode 4 you deployed to two virtual machines with Ansible. In episode 5 you deploy to **Kubernetes**: a program that runs your app for you, keeps the number of copies you asked for, and replaces any copy that dies. You no longer say "start this container on that server". You say "I want three copies of this version", and Kubernetes makes it so.

The pipeline, the tests, the quality gate and the Docker image stay the same. Only the Deploy and Operate steps change.

| Episode 4 | Episode 5 |
|---|---|
| Two Lima VMs | One kind cluster with three nodes |
| `ansible/`, `runner/deploy.sh` | `k8s/`, `runner/deploy-k8s.sh` |
| One container per server | Three pods per environment |
| Health check, then automatic roll back by Ansible | Probes, rolling update, `kubectl rollout undo` |

The episode-4 version is kept as the git tag `ep4-ansible` (release 1.4.2). To go back to it: `git checkout ep4-ansible`. The `ansible/`, `servers/` and `runner/deploy.sh` files are still in `main`.

## What you need

- **Docker**, running. Docker Desktop is free for personal use, education and small businesses. At a larger company use Colima or Rancher Desktop, both free.
- **kind**: `brew install kind`. kind makes a Kubernetes cluster out of Docker containers.
- **kubectl**: `brew install kubectl`, or the one Docker Desktop ships. kubectl is the command you type to talk to Kubernetes.
- Memory: the cluster uses about 1.7 GB with both environments running (we measured about 820 MiB for the control plane and 430 MiB for each worker). Give Docker at least 4 GB.

## Before anything: which cluster does kubectl talk to?

kubectl keeps a list of clusters in `~/.kube/config`. Each entry is a **context**, and one of them is the current one. Every kubectl command goes to the current context. If you have used kubectl at work, the current context may be a real company cluster.

```bash
kubectl config current-context
```

What you should see: the name of one context. Before you create the lab cluster, it may be empty or something else. After `bash scripts/k8s-up.sh`, the lab cluster's context is `kind-lab`.

Every script in this repo names `kind-lab` itself, and `runner/deploy-k8s.sh` also refuses to deploy unless that context points at a cluster on this laptop (`https://127.0.0.1:...`), so none of them can deploy to another cluster. Every command on this page does the same: it passes `--context kind-lab`. Do the same in your own commands.

## The words

- **Cluster**: all of Kubernetes, with the machines it runs on.
- **Node**: one machine in the cluster. Here each node is a Docker container. The lab cluster has one control plane node (it decides) and two worker nodes (they run your app).
- **Pod**: one running copy of your app. It holds your container.
- **Namespace**: a named folder inside a cluster. `staging` and `production` are two namespaces in the same cluster. Real companies usually give production its own cluster.
- **Manifest**: a YAML file that describes something you want Kubernetes to have.
- **Kustomize**: a tool built into kubectl. `k8s/base/` holds what staging and production share. Each folder in `k8s/overlays/` adds what differs (the namespace and the port).

## Step 1: Start the cluster and deploy (laptop path)

If episode 4's servers are running, stop them first. They use the same ports, 8081 and 8082:

```bash
bash servers/down.sh
```

Then:

```bash
bash scripts/k8s-up.sh
```

The script:

1. Creates the cluster `lab` from `k8s/kind-config.yaml`, if it is not there yet.
2. Builds the app as the image `status-board:local-<commit>`.
3. Copies the image into the nodes with `kind load`. The nodes cannot see your laptop's Docker images otherwise.
4. Deploys staging, then production, with `runner/deploy-k8s.sh`.

Open http://localhost:8081 (staging) and http://localhost:8082 (production). In `k8s/kind-config.yaml`, kind maps node port 30081 to your laptop's port 8081, and 30082 to 8082. Both are bound to `127.0.0.1`, so only your laptop can reach them.

What you should see: the script ends with `DEPLOYED <version> to production`, then the two addresses. The page footer says "served by" and a pod name. A browser reuses one connection, so reloading often shows the same pod. `curl` opens a new connection every time, so its pod name changes.

```bash
curl http://localhost:8081/version
```

What you should see: JSON with `version`, `commit` and `pod`.

From our run (names and times differ on yours):

```text
{"commit":"7c40760b76a20f2758c226eeb0f4ea6c6da08a4a","pod":"status-board-fd94fd459-zlgqm","version":"1.4.2"}
```

```bash
kubectl --context kind-lab -n staging get pods
```

What you should see: three pods, each `1/1` and `Running`.

From our run (names and times differ on yours):

```text
NAME                           READY   STATUS    RESTARTS   AGE
status-board-fd94fd459-g5ncb   1/1     Running   0          3m20s
status-board-fd94fd459-nxktm   1/1     Running   0          3m14s
status-board-fd94fd459-zlgqm   1/1     Running   0          3m17s
```

Remove everything when you are done:

```bash
bash scripts/k8s-down.sh
```

This deletes the cluster and both environments. Your Docker images stay.

## Step 2: Deployment (desired state)

A **Deployment** says what you want: this image, three copies, these settings. Kubernetes keeps comparing what you asked for with what is running, and fixes any difference. This idea is called **desired state**. It is in `k8s/base/deployment.yaml` as `replicas: 3`.

Delete one pod. In one terminal:

```bash
kubectl --context kind-lab -n staging get pods -w
```

In a second terminal, use a pod name from the first:

```bash
kubectl --context kind-lab -n staging delete pod <name>
```

What you should see: the pod you deleted goes to `Terminating`, a new pod with a new name appears, goes through `ContainerCreating`, and reaches `1/1 Running`. There are three pods again. Press Ctrl-C to stop the watch.

From our run (names and times differ on yours):

```text
status-board-fd94fd459-g5ncb   1/1     Terminating         0          3m21s
status-board-fd94fd459-848vg   0/1     Pending             0          0s
status-board-fd94fd459-848vg   0/1     ContainerCreating   0          0s
status-board-fd94fd459-848vg   0/1     Running             0          0s
status-board-fd94fd459-848vg   1/1     Running             0          3s
status-board-fd94fd459-g5ncb   0/1     Completed           0          3m27s
```

The new pod is ready in about 3 seconds. The old one takes about 6 seconds to go: it waits 5 seconds (`preStop` in the Deployment) so requests already on their way still get an answer.

Never start or stop pods by hand to change how many there are. Change `replicas` in the file and deploy again.

## Step 3: Service (one address for all the pods)

Pods come and go, and each new pod gets a new address. A **Service** is one address that does not change. It sends each request to one of the pods that are ready and carry the label `app=status-board`. A **label** is a name tag on a pod. The Service finds its pods by that tag.

The list of pods behind a Service is its **endpoints**:

```bash
kubectl --context kind-lab -n staging describe endpointslice -l kubernetes.io/service-name=status-board
```

What you should see: three endpoints, one for each ready pod, each with its pod name.

From our run (names and times differ on yours):

```text
Name:         status-board-dh6lf
Namespace:    staging
...
Endpoints:
  - Addresses:  10.244.2.9
    Conditions:
      Ready:    true
    TargetRef:  Pod/status-board-fd94fd459-nxktm
    NodeName:   lab-worker2
  ... (two more, each Ready: true)
```

The Service in this repo is a **NodePort**: it listens on a fixed port on every node. That is how kind makes it reachable at `localhost:8081`.

### Watch the traffic

```bash
bash scripts/k8s-traffic.sh 8081
```

It asks `/version` five times a second and keeps a running count of requests that worked and failed. Use `8082` for production. Leave it running while you do the next steps, then press Ctrl-C.

What you should see: a line with a green ok count that goes up. After Ctrl-C, a summary of how many requests each pod answered. All three pods have a share.

From our run (names and times differ on yours):

```text
39 ok, 0 failed. Answered by:
  status-board-fd94fd459-zlgqm  15
  status-board-fd94fd459-nxktm  13
  status-board-fd94fd459-848vg  11
```

The Service picks a pod at random for each request, not in turn, so the shares are close but not equal.

## Step 4: Probes (ready and alive are different questions)

Kubernetes asks each pod two questions, by calling `/health`. Both are in `k8s/base/deployment.yaml`.

| Probe | Question | If the answer is no |
|---|---|---|
| Readiness | Are you ready for requests? | The pod stays running, but the Service sends it nothing. |
| Liveness | Are you still alive? | Kubernetes restarts the container. `RESTARTS` goes up by one. |

Not ready means "leave me alone for now". Not alive means "start me again". A pod that is slow to start, or busy, should be not ready. Only a pod that is stuck for good should be not alive. For that reason the liveness probe asks only about the app itself, never about other services.

You will see both probes work in [10 Diagnose](10-diagnose.md), when you freeze a pod.

## Step 5: Requests and limits

Each container says how much CPU and memory it needs and how much it may use. In `k8s/base/deployment.yaml`:

```yaml
resources:
  requests:
    cpu: 50m
    memory: 96Mi
  limits:
    cpu: 250m
    memory: 192Mi
```

- **Requests** are what the scheduler books on a node. The **scheduler** is the part of Kubernetes that picks a node for each new pod. If no node has that much room left, the pod waits as `Pending`.
- **Limits** are the most the container may use.
  - Over the CPU limit, the app is slowed down.
  - Over the memory limit, the container is killed. The status says `OOMKilled` (out of memory) and the exit code is 137.

`50m` means 50 millicores: one twentieth of a CPU. `Mi` means mebibytes.

The app uses about 74 MiB when idle, so it requests 96Mi and is limited to 192Mi. A limit below what the app needs kills it again and again. You will cause that on purpose in [10 Diagnose](10-diagnose.md).

## Step 6: Rolling update

Deploy a new version and Kubernetes does not stop the old one first. The Deployment has this strategy:

```yaml
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0
```

`maxSurge: 1` allows one extra pod during an update. `maxUnavailable: 0` means there are never fewer ready pods than `replicas`. So: Kubernetes starts one new pod, waits until it is ready, then removes one old pod, and repeats. Users never see a gap.

Try it. Start the traffic script in one terminal, and in a second terminal change `VERSION` or any file and deploy again:

```bash
bash scripts/k8s-traffic.sh 8081
```

```bash
bash scripts/k8s-up.sh
```

On the GitHub path, commit and push the change instead.

What you should see: the second terminal shows `get pods` with old and new pods side by side for a short while. The traffic script's failed count stays at 0.

From our run (names and times differ on yours):

```text
NAME                            READY   STATUS        RESTARTS   AGE
status-board-85bd45b469-fvddk   1/1     Terminating   0          5m3s
status-board-85bd45b469-zcqmb   1/1     Terminating   0          5m10s
status-board-fd94fd459-g5ncb    1/1     Running       0          11s
status-board-fd94fd459-nxktm    1/1     Running       0          5s
status-board-fd94fd459-zlgqm    1/1     Running       0          8s
```

In our run the update took about 11 seconds, and the traffic script, which ran for about five minutes around it (1,468 requests), counted 0 failed.

### What if the new version never becomes ready?

The Deployment has `progressDeadlineSeconds: 90`. A rollout that has not finished after 90 seconds is marked as stuck. Kubernetes does **not** undo it for you. The old pods keep serving users, and the new pod stays there so you can look at it. A person decides what to do next.

`runner/deploy-k8s.sh` waits up to 120 seconds. If the rollout is stuck, it prints what Kubernetes saw and what the app said, and exits with an error. It does not undo anything either. If you want that, the comment at the top of the script shows where to add one line.

### Rollout history and undo

Every deploy is one **revision**. `deploy-k8s.sh` writes the version next to each revision:

```bash
kubectl --context kind-lab -n staging rollout history deployment/status-board
```

What you should see: a table with a REVISION column and a CHANGE-CAUSE column. The change cause looks like `1.4.2 (7c40760)`: the version, then the commit.

From our run (names and times differ on yours):

```text
REVISION  CHANGE-CAUSE
1         1.4.2 (7c40760)
2         1.5.0 (local-test150)
3         1.5.1 (local-test151)
```

To go back one revision:

```bash
kubectl --context kind-lab -n staging rollout undo deployment/status-board
```

What you should see: `deployment.apps/status-board rolled back`. After a normal update, the pods change back one at a time. After a stuck rollout it is instant: the old pods never left, and the stuck pod is removed.

kubectl also prints a warning that rolling back "will not update the kubectl.kubernetes.io/last-applied-configuration annotation". It is right: the cluster is back on the old version, but your file still says the new one. Undo is the emergency brake. The real fix is to correct the file and deploy again.

The revision you went back to gets a new number, so after one undo the history reads 1, 3, 4.

Kubernetes keeps the last five revisions (`revisionHistoryLimit: 5`).

## Compare with episode 4

| Question | Ansible and VMs | Kubernetes |
|---|---|---|
| Who restarts a crashed app? | Docker's restart policy, one container | Kubernetes, for every pod |
| How many copies run? | One per server | `replicas: 3` |
| Zero downtime deploy? | No: the container is replaced | Yes: rolling update |
| What happens on a bad deploy? | The script rolls back by itself | The rollout stops and waits for a person |
| How do you go back? | The script starts the previous image | `kubectl rollout undo` |

Neither is better in every case. Kubernetes gives you more, and has more words to learn.

## You should see

- `kubectl --context kind-lab get nodes` lists three nodes.
- `kubectl --context kind-lab -n staging get pods` and the same for `production` list three pods each, `1/1 Running`.
- http://localhost:8081 and http://localhost:8082 answer, and the page footer shows the name of the pod that served you.

From our run (names and times differ on yours):

```text
NAME                STATUS   ROLES           AGE   VERSION
lab-control-plane   Ready    control-plane   19m   v1.37.0
lab-worker          Ready    <none>          19m   v1.37.0
lab-worker2         Ready    <none>          19m   v1.37.0
```

Next: [10 Diagnose](10-diagnose.md).
