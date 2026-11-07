# 01 Plan and code

Work starts as an issue, becomes a branch, then a pull request (PR), and ends in a review. Nobody pushes straight to `main`.

## 1. Plan: write an issue

In your repo on GitHub: **Issues**, **New issue**. Give it a short title, such as "Show response time on the board". Say what done looks like.

## 2. Code: branch, commit

```bash
git checkout -b show-response-time
# edit files
git add app/board.py tests/test_board.py
git commit -m "Show response time on the board"
git push -u origin show-response-time
```

A branch is your own copy of the history. `main` stays safe while you work.

Write a test with every change. The pipeline fails if coverage drops ([03](03-quality-gate.md)).

## 3. Pull request

On GitHub, press **Compare & pull request**. Write "Closes #1" in the description to link the issue (use your issue number).

Opening the PR starts the `CI` workflow (`.github/workflows/ci.yml`). It runs on GitHub's machines. Read its result at the bottom of the PR.

## 4. Review

A teammate reads the change and leaves comments. Fix them with more commits on the same branch. When the checks are green and someone approves, press **Merge**.

Merging into `main` starts the `Pipeline` workflow ([07](07-deploy.md)).

## Make a red check block the merge

Out of the box, a failing check only warns you; GitHub still lets you merge. To make it a hard rule:
**Settings → Rules → Rulesets → New ruleset → New branch ruleset**. Name it `protect main`, set **Enforcement status**
to **Active**, add the target **Include default branch**, tick **Require status checks to pass**, and add the three
checks: **Lint and unit tests**, **Quality gate (SonarQube)** and **Docker image builds and starts**. Save.

From then on, a change can only reach `main` through a pull request whose checks are green. Pushing straight to
`main` is refused.

## Update your local copy

```bash
git checkout main
git pull
```

## You should see

- `git push` ends with a line offering to create a pull request, with a link.
- On the PR page, a check named **CI / Lint and unit tests** appears, then **Quality gate (SonarQube)** and **Docker image builds and starts**.
- After you merge, the **Actions** tab shows a new **Pipeline** run for `main`.
