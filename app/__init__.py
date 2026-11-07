"""Status Board: a tiny Flask app that checks three websites and shows their state."""

import os

from flask import Flask, Response, jsonify, render_template

from app.board import check_all


def version_info():
    """Read the running version and commit from the environment (set at image build time)."""
    return {
        "version": os.environ.get("APP_VERSION") or "dev",
        "commit": os.environ.get("GIT_SHA") or "local",
    }


def create_app():
    app = Flask(__name__)

    @app.get("/")
    def index():
        info = version_info()
        return render_template(
            "board.html",
            sites=check_all(),
            version=info["version"],
            commit=info["commit"][:7],
        )

    @app.get("/health")
    def health():
        # No network here: this only says "the process is up".
        return Response("OK", mimetype="text/plain")

    @app.get("/version")
    def version():
        return jsonify(version_info())

    return app
