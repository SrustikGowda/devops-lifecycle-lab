"""Status Board: a tiny Flask app that checks three websites and shows their state."""

import os
import socket

from flask import Flask, Response, jsonify, render_template

from app.board import check_all


def version_info():
    """The running version and commit (set at image build time), and which copy of the app answered.

    In Kubernetes the hostname is the pod's name; in plain Docker it is the container ID.
    """
    return {
        "version": os.environ.get("APP_VERSION") or "dev",
        "commit": os.environ.get("GIT_SHA") or "local",
        "pod": socket.gethostname(),
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
            pod=info["pod"],
        )

    @app.get("/health")
    def health():
        # No network here: this only says "the process is up".
        return Response("OK", mimetype="text/plain")

    @app.get("/version")
    def version():
        return jsonify(version_info())

    return app
