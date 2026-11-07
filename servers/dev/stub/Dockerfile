# A tiny stand-in for the real app, for testing the deploy before the pipeline exists.
# It serves the files in /srv; GET /health returns 200 because a file named "health" is there.
#   good: listens on 8080 (like the real app)  -> healthy
#   bad:  listens on 9090 (wrong port)         -> /health never answers, the deploy rolls back
FROM python:3.12-slim
ARG PORT=8080
ENV PORT=${PORT} \
    PYTHONUNBUFFERED=1
WORKDIR /srv
RUN echo OK > health
USER nobody
CMD ["sh", "-c", "exec python -m http.server \"$PORT\""]
