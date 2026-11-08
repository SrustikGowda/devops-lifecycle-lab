# 10 Diagnose

Something is wrong in the cluster. Where do you look? Ask three questions, in this order.

| Question | Command | It tells you |
|---|---|---|
| 1. What state is it in? | `get pods` | `Pending`, `Running` but `0/1`, `CrashLoopBackOff`, `OOMKilled` |
| 2. What did Kubernetes see? | `describe pod` | The **Events** at the bottom: scheduling, probes, kills |
| 3. What did the app say? | `logs` | The app's own output |

Kubernetes writes events about the pod. The app writes logs about itself. The cause is usually in one of the two.

```bash
kubectl --context kind-lab -n staging get pods
kubectl --context kind-lab -n staging describe pod <name>
kubectl --context kind-lab -n staging logs <name>
```

If a container has restarted, `logs` shows the new container, which may have nothing to say yet. Add `--previous` to read the one before the restart:

```bash
kubectl --context kind-lab -n staging logs <name> --previous
```

What you should see: `get pods` lists the pods with READY, STATUS and RESTARTS columns. `describe pod` ends with an Events table. `logs` prints the lines gunicorn wrote.

Before you start, make sure the lab is healthy: three pods `1/1 Running` in staging ([09](09-kubernetes.md)). To watch users while you break things, run `bash scripts/k8s-traffic.sh 8081` in a spare terminal.

## What the states mean

| Status | Meaning |
|---|---|
| `Pending` | No node can take the pod yet. |
| `Running`, READY `0/1` | The container runs, but the readiness probe says no. No traffic goes to it. |
| `CrashLoopBackOff` | The container keeps stopping. Kubernetes waits a little longer after each restart. |
| `OOMKilled` (in `describe pod`, Last State) | The container used more memory than its limit and was killed. Exit code 137. |

## Exercise 1: the wrong port

This is the mistake from episode 4 ([07](07-deploy.md)), one layer down: the port is wrong in the Kubernetes file, not in the Dockerfile.

Cause it:

```bash
bash scripts/break-it.sh k8s-port
```

Then deploy. On the laptop path:

```bash
bash scripts/k8s-up.sh
```

On the GitHub path, commit and push (through a pull request, as usual).

Keep `kubectl --context kind-lab -n staging get pods -w` running in another terminal.

What you should see: on the GitHub path, the tests, the quality gate and the image smoke test all pass, because nothing in CI reads `k8s/`. In the cluster, one new pod appears and stays `0/1`. The three old pods stay `1/1` and keep answering. After about 90 seconds the rollout is marked stuck. `deploy-k8s.sh` prints `ROLLOUT STUCK`, what Kubernetes saw, and what the app said, then exits with an error.

From our run (names and times differ on yours):

```text
error: deployment "status-board" exceeded its progress deadline

ROLLOUT STUCK: 1.5.1 never became ready on staging. The previous version is still serving users.
NAME                            READY   STATUS    RESTARTS        AGE
status-board-6c7fcdcdd-fh58r    0/1     Running   3 (5s ago)      91s
status-board-85bd45b469-9bdg6   1/1     Running   1 (2m50s ago)   3m42s
status-board-85bd45b469-fvddk   1/1     Running   0               3m49s
status-board-85bd45b469-zcqmb   1/1     Running   0               3m56s
```

In our run the traffic script counted 450 requests during the stuck rollout, and 0 failed. The new pod also restarted 3 times: the liveness probe asks port 8080 too. Restarting doesn't help, because the new pod's settings are wrong, and every restart uses the same settings.

Find the cause. Question 1: the new pod is `Running` but `0/1`. Question 2:

```bash
kubectl --context kind-lab -n staging describe pod <the new pod>
```

What you should see: in Events, `Readiness probe failed` and `Liveness probe failed` for port 8080, `connection refused`.

From our run (names and times differ on yours):

```text
Warning  Unhealthy  71s (x3 over 81s)   kubelet  Liveness probe failed: Get "http://10.244.1.8:8080/health": dial tcp 10.244.1.8:8080: connect: connection refused
Warning  Unhealthy  54s (x22 over 91s)  kubelet  Readiness probe failed: Get "http://10.244.1.8:8080/health": dial tcp 10.244.1.8:8080: connect: connection refused
Normal   Killing    11s (x3 over 71s)   kubelet  Container status-board failed liveness probe, will be restarted
```

Question 3:

```bash
kubectl --context kind-lab -n staging logs <the new pod>
```

What you should see: gunicorn says it is listening on port 9090. The probes ask port 8080. Nobody answers.

From our run (names and times differ on yours):

```text
[2026-11-08 06:02:17 +0000] [1] [INFO] Starting gunicorn 26.2.0
[2026-11-08 06:02:17 +0000] [1] [INFO] Listening at: http://0.0.0.0:9090 (1)
```

Fix it. First put the cluster back:

```bash
kubectl --context kind-lab -n staging rollout undo deployment/status-board
```

Then put the file back:

```bash
git checkout -- .
```

On the GitHub path, if you already pushed the commit, revert it instead (`git revert <commit>`), or the next deploy brings the mistake back.

What you should see: `deployment.apps/status-board rolled back`, the stuck pod disappears, and `get pods` shows three pods `1/1 Running`. kubectl also warns about `last-applied-configuration`: that's because your file still has the mistake until the next step ([09](09-kubernetes.md#rollout-history-and-undo)).

Production was never touched. On the GitHub path the production job needs staging to pass, and `k8s-up.sh` stops as soon as staging fails.

## Exercise 2: a frozen pod

Now the app does not crash. It just stops answering, as it would in a deadlock.

```bash
bash scripts/k8s-freeze.sh staging
```

It picks one ready pod and stops the gunicorn workers inside it. Watch with `kubectl --context kind-lab -n staging get pods -w`, and keep `bash scripts/k8s-traffic.sh 8081` running.

What you should see, in order:

1. After about 5 seconds the pod goes from `1/1` to `0/1`. The readiness probe failed three times in a row. The Service stops sending it requests.
2. After about 30 seconds `RESTARTS` goes from 0 to 1. The liveness probe gave up at about 15 seconds. The restart itself takes another 15, because the frozen workers can't shut down, so Kubernetes waits out the 15-second grace period before it kills them.
3. About 2 seconds later the pod is back to `1/1`.

From our run (names and times differ on yours):

```text
status-board-fd94fd459-848vg   1/1     Running   0            24s
status-board-fd94fd459-848vg   0/1     Running   0            32s
status-board-fd94fd459-848vg   0/1     Running   1 (1s ago)   57s
status-board-fd94fd459-848vg   1/1     Running   1 (3s ago)   59s
```

A few requests can fail in the seconds before readiness removes the pod: the Service still sends some requests to it until three probes have failed. Press Ctrl-C on the traffic script and read the failed count.

From our run (names and times differ on yours):

```text
165 ok, 5 failed. Answered by:
  status-board-fd94fd459-zlgqm  89
  status-board-fd94fd459-nxktm  70
  status-board-fd94fd459-848vg  6
```

In two runs, 3 and 5 requests failed, all in the first few seconds. Checking more often would lose fewer requests but raise more false alarms: that is the trade-off you tune with `periodSeconds` and `failureThreshold`.

Find the cause:

```bash
kubectl --context kind-lab -n staging describe pod <the frozen pod>
```

What you should see: in Events, `Readiness probe failed`, then `Liveness probe failed` and a line saying the container will be restarted.

From our run (names and times differ on yours):

```text
Warning  Unhealthy  21s (x3 over 31s)  kubelet  Liveness probe failed: Get "http://10.244.1.6:8080/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
Normal   Killing    21s                kubelet  Container status-board failed liveness probe, will be restarted
Warning  Unhealthy  7s (x15 over 33s)  kubelet  Readiness probe failed: Get "http://10.244.1.6:8080/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

`context deadline exceeded` means "no answer within the 1-second timeout". Compare it with exercise 1's `connection refused`, which means "nothing is listening on that port at all".

Fix: nothing. Kubernetes already did. This is why the Deployment has probes.

## Exercise 3: not enough memory

Cause it:

```bash
bash scripts/break-it.sh k8s-memory
```

It sets the memory request and limit to 32Mi. The app needs about 74 MiB. Deploy as in exercise 1 (laptop: `bash scripts/k8s-up.sh`; GitHub: commit and push).

What you should see: the new pod starts, is killed, starts again, and is killed again. `STATUS` shows `OOMKilled`, then `CrashLoopBackOff`, and `RESTARTS` climbs. The old pods keep serving. The rollout is marked stuck and the script exits with an error.

From our run (names and times differ on yours):

```text
NAME                            READY   STATUS             RESTARTS      AGE
status-board-85b696874b-gb7wd   0/1     CrashLoopBackOff   3 (44s ago)   91s
```

In our run the traffic script counted 459 requests during this stuck rollout, and 0 failed.

Find the cause:

```bash
kubectl --context kind-lab -n staging describe pod <the new pod>
```

What you should see: under the container, `Last State: Terminated`, `Reason: OOMKilled`, `Exit Code: 137`.

From our run (names and times differ on yours):

```text
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
```

The logs may show very little. The kernel killed the process, so the app had no chance to say anything. That is a clue too:

```bash
kubectl --context kind-lab -n staging logs <the new pod> --previous
```

Fix it the same way as exercise 1: `kubectl --context kind-lab -n staging rollout undo deployment/status-board`, then `git checkout -- .`.

What you should see: three pods `1/1 Running`, no `CrashLoopBackOff`.

## Two small demos

These two pods are not part of the Deployment. They are labelled `app=demo`, so the Deployment does not treat them as its own.

### A pod that asks for too much: `Pending`

```bash
kubectl --context kind-lab -n staging apply -f k8s/demos/greedy-pod.yaml
kubectl --context kind-lab -n staging get pod greedy
kubectl --context kind-lab -n staging describe pod greedy
kubectl --context kind-lab -n staging delete pod greedy
```

The pod requests 100 whole CPUs. No node has that. The scheduler cannot place it.

What you should see: `greedy` stays `Pending`. In Events: `Insufficient cpu`.

From our run (names and times differ on yours):

```text
Warning  FailedScheduling  25s  default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint(s), 2 Insufficient cpu. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

"1 node(s) had untolerated taint(s)" is the control plane: it doesn't run apps. The two workers don't have 100 CPUs.

### A pod with too little memory: `OOMKilled`

```bash
kubectl --context kind-lab -n staging apply -f k8s/demos/tiny-memory-pod.yaml
kubectl --context kind-lab -n staging get pod tiny-memory -w
kubectl --context kind-lab -n staging describe pod tiny-memory
kubectl --context kind-lab -n staging delete pod tiny-memory
```

What you should see: `tiny-memory` is killed and restarted again and again. In `describe pod`: Last State `Terminated`, Reason `OOMKilled`.

From our run (names and times differ on yours):

```text
NAME          READY   STATUS      RESTARTS      AGE
tiny-memory   0/1     OOMKilled   2 (22s ago)   25s
```

Delete both pods when you are done, as shown in the commands.

## Another case: the Service can't reach the pods

All pods are `1/1 Running`, yet the address does not answer. Look at the Service's endpoints:

```bash
kubectl --context kind-lab -n staging describe endpointslice -l kubernetes.io/service-name=status-board
```

If the list of endpoints is empty, the Service found no ready pod. A common cause is a typo in the Service's `selector` in `k8s/base/service.yaml`, for example `app: status-bord`. It then looks for a label no pod has. Compare the selector with the pods' labels:

```bash
kubectl --context kind-lab -n staging get pods --show-labels
kubectl --context kind-lab -n staging get service status-board -o jsonpath='{.spec.selector}'
```

What you should see: the pods have `app=status-board`. If the Service's selector shows anything else, that is the bug. Fix the file and deploy again.

From our run (names and times differ on yours):

```text
$ kubectl --context kind-lab -n staging get endpointslice -l kubernetes.io/service-name=status-board
NAME                 ADDRESSTYPE   PORTS     ENDPOINTS   AGE
status-board-dh6lf   IPv4          <unset>   <unset>     8m30s
$ curl -sS localhost:8081/version
curl: (52) Empty reply from server
```

Through kind's port mapping, a Service with no pods gives `Empty reply from server`, not `connection refused`.

## You should see

After the three exercises and the demos, `get pods` in staging shows three pods `1/1 Running` and no `greedy` or `tiny-memory`. `git status` shows no changes to `k8s/`.
