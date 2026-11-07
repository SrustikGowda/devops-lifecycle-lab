# 03 Quality gate (SonarQube)

A quality gate is a rule that says "this build is not good enough". Ours: **fail if overall test coverage is below 80%**.

## SonarQube does not run tests

`pytest` runs the tests and writes `coverage.xml`. SonarQube reads that file (`sonar.python.coverage.reportPaths` in `sonar-project.properties`), checks the numbers against the gate, and answers pass or fail. Run `pytest` first, or the scan stops with "coverage.xml not found".

## Start SonarQube

Docker Desktop must be running.

```bash
docker compose -f sonarqube/compose.yml up -d
```

The first start takes about 1 to 2 minutes. Open http://localhost:9000. Log in with `admin` / `admin`. SonarQube then makes you choose a new password in the browser.

## Set up the gate and scan

```bash
export SONAR_TOKEN=$(bash sonarqube/setup.sh)
bash sonarqube/scan.sh
```

`setup.sh` waits until SonarQube is up, creates the gate `lab-gate`, makes it the default, and prints a token. `scan.sh` runs the scanner in Docker and waits for the gate result. On Apple silicon the scan takes about 90 seconds, because the scanner image is amd64 and runs emulated.

Note: `setup.sh` logs in as `admin:admin` by default. If you changed the password, pass it: `SONAR_ADMIN=admin:<your-password> bash sonarqube/setup.sh`.

## Why a custom gate and not "Sonar way"

SonarQube's built-in gate "Sonar way" only judges new code. On the first scan of a project there is no new code yet, so it always passes. `lab-gate` judges the whole project, so a drop in coverage fails right away.

## Make it fail on purpose

```bash
bash scripts/break-it.sh coverage
pytest
export SONAR_TOKEN=$(bash sonarqube/setup.sh)
bash sonarqube/scan.sh
echo $?
git checkout -- .
```

## Stop it

```bash
docker compose -f sonarqube/compose.yml down
```

Add `-v` to delete its data too.

## You should see

Clean code: the scan ends with

```
QUALITY GATE STATUS: PASSED
```

After `break-it.sh coverage`: `pytest` still passes 11 tests, coverage is 74%, the scan ends with

```
QUALITY GATE STATUS: FAILED
```

and `echo $?` prints a non-zero number. In the dashboard at http://localhost:9000, the project "DevOps Lifecycle Lab" shows the gate result.
