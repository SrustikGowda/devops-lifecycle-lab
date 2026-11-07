# Jenkins vs GitHub Actions

Many companies use Jenkins. The ideas are the same as here. Only the names change.

| Idea | Jenkins | GitHub Actions (this lab) |
|---|---|---|
| The server that schedules work | Controller | GitHub |
| A machine that does the work | Agent (a "node") | Runner (`runner/README.md`) |
| Pipeline as code | `Jenkinsfile` | Workflow YAML in `.github/workflows/` |
| A big phase | `stage` | `job` |
| One command | `sh` step | `run:` step |
| Reusable building blocks | Plugins | Actions (`uses:`) |
| Stored passwords and tokens | Credentials | Secrets (`secrets.GITHUB_TOKEN`) |
| Pause for a human | `input` step | Environment with required reviewers |
| Pick a machine | `agent { label 'lab' }` | `runs-on: [self-hosted, lab]` |
| Run inside a container | `agent { docker { image '...' } }` | `container: python:3.12-slim` |
| Run on a trigger | SCM polling or webhook | `on: push`, `on: pull_request` |

## A Jenkinsfile for this pipeline

**Illustration only: this lab runs on GitHub Actions; this Jenkinsfile has not been run.**

```groovy
pipeline {
  agent none
  environment {
    IMAGE_NAME = "ghcr.io/your-name/devops-lifecycle-lab"
  }
  stages {
    stage('Test') {
      agent { docker { image 'python:3.12-slim' } }
      steps {
        sh 'pip install --no-cache-dir -r requirements-dev.txt'
        sh 'ruff check .'
        sh 'pytest'
        stash name: 'coverage', includes: 'coverage.xml'
      }
    }
    stage('Quality gate') {
      agent { label 'lab' }
      steps {
        unstash 'coverage'
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh 'bash sonarqube/scan.sh'
        }
      }
    }
    stage('Package') {
      agent { label 'lab' }
      steps {
        sh 'docker build --build-arg APP_VERSION="$(cat VERSION)" --build-arg GIT_SHA="$GIT_COMMIT" -t "$IMAGE_NAME:$GIT_COMMIT" .'
        withCredentials([usernamePassword(credentialsId: 'ghcr-login', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh 'echo "$REG_PASS" | docker login ghcr.io -u "$REG_USER" --password-stdin'
          sh 'docker push "$IMAGE_NAME:$GIT_COMMIT"'
        }
      }
    }
    stage('Deploy to staging') {
      agent { label 'lab' }
      steps {
        sh 'bash runner/deploy.sh staging "$IMAGE_NAME:$GIT_COMMIT" "$(cat VERSION)"'
        sh 'curl -fsS http://localhost:8081/version'
      }
    }
    stage('Approve production') {
      steps {
        input message: 'Staging is up. Deploy to production?', submitter: 'admin'
      }
    }
    stage('Deploy to production') {
      agent { label 'lab' }
      steps {
        sh 'bash runner/deploy.sh production "$IMAGE_NAME:$GIT_COMMIT" "$(cat VERSION)"'
        sh 'curl -fsS http://localhost:8082/version'
      }
    }
  }
}
```

Differences to know:

- Our workflow starts SonarQube fresh in each run and builds for two CPU types. The Jenkinsfile above assumes a SonarQube that already exists and builds for one.
- `agent none` plus a per-stage agent is how Jenkins picks a machine for each stage, like `runs-on` per job.
- The `input` step sits in its own stage with no agent, so it does not hold a machine while it waits.

## You should see

Nothing to run on this page. Compare it with `.github/workflows/pipeline.yml`: each Jenkins `stage` has a matching job or step there.
