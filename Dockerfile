# Stage 1: install the dependencies into a virtual environment.
FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Stage 2: the small runtime image.
FROM python:3.12-slim

# Set at build time: --build-arg APP_VERSION=1.0.0 --build-arg GIT_SHA=<commit>
ARG APP_VERSION=dev
ARG GIT_SHA=local
ARG SOURCE_URL=""
LABEL org.opencontainers.image.source=$SOURCE_URL

ENV PORT=8080
ENV APP_VERSION=$APP_VERSION \
    GIT_SHA=$GIT_SHA \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

RUN useradd --system --uid 10001 --no-create-home appuser
WORKDIR /srv
COPY --from=build /opt/venv /opt/venv
COPY app ./app
USER appuser

EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT}/health', timeout=2)"

# "sh -c" so ${PORT} is expanded; "exec" so gunicorn becomes PID 1 and gets stop signals.
# --threads 4: each worker answers 4 requests at once, so /health still answers while the page waits on the three
# websites (up to 2 s each). Kubernetes asks /health every few seconds and gives up after 1 s.
# --no-control-socket: we don't use gunicorn's control tool, and appuser has no home folder to put its socket in
# (without this flag, every start logs a confusing "Permission denied: '/home/appuser'").
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 2 --threads 4 --no-control-socket --access-logfile - 'app:create_app()'"]
