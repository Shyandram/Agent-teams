#!/usr/bin/env python3
"""Read-only monitor server for an agent team.

Standard library only (works on Python 3.8+). Serves exactly two things:

    GET /            -> monitor/index.html
    GET /api/state   -> the JSON document from collectors.collect_state()

There are deliberately no POST/PUT/DELETE handlers: this dashboard observes a
fleet, it never drives one.

    python3 monitor/server.py --project /abs/path [--port 8787]
                              [--bind 127.0.0.1] [--refresh 2]
"""

import argparse
import errno
import getpass
import json
import os
import socket
import sys
import threading
import time

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import collectors  # noqa: E402  (after sys.path fix, by design)

HERE = os.path.dirname(os.path.abspath(__file__))
INDEX_PATH = os.path.join(HERE, "index.html")

# Rapid polling (or several open tabs) must not spawn a subprocess storm.
CACHE_TTL_SECONDS = 1.0

LOCAL_BINDS = ("127.0.0.1", "localhost", "::1")


class StateCache(object):
    """Serialised, briefly-cached access to the collectors."""

    def __init__(self, project, ttl=CACHE_TTL_SECONDS):
        self.project = project
        self.ttl = ttl
        self._lock = threading.Lock()
        self._payload = None
        self._fetched_at = 0.0

    def get(self):
        with self._lock:
            now = time.time()
            if self._payload is not None and (now - self._fetched_at) < self.ttl:
                return self._payload
            try:
                state = collectors.collect_state(self.project)
            except Exception as exc:            # never 500 on a collector bug
                state = {
                    "project": self.project,
                    "project_name": os.path.basename(self.project),
                    "generated_at": collectors.iso_utc(time.time()),
                    "roles": (self._payload or {}).get("roles", []),
                    "warnings": ["collector failure: %s" % exc],
                    "degraded": True,
                }
            self._payload = state
            self._fetched_at = time.time()
            return state


def _build_handler(cache, refresh_seconds, quiet=True):

    class MonitorHandler(BaseHTTPRequestHandler):
        server_version = "agent-teams-monitor/1.0"
        protocol_version = "HTTP/1.1"

        # --- plumbing -----------------------------------------------------

        def log_message(self, fmt, *args):
            if not quiet:
                sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

        def _send(self, code, body, content_type, extra_headers=()):
            if isinstance(body, str):
                body = body.encode("utf-8")
            try:
                self.send_response(code)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(body)))
                for key, value in extra_headers:
                    self.send_header(key, value)
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass                                   # browser navigated away

        # --- routes -------------------------------------------------------

        def do_GET(self):
            path = self.path.split("?", 1)[0].split("#", 1)[0]
            if path in ("/", "/index.html"):
                return self._serve_index()
            if path == "/api/state":
                return self._serve_state()
            self._send(404, "not found\n", "text/plain; charset=utf-8")

        def do_HEAD(self):
            self.do_GET()

        def _serve_index(self):
            try:
                with open(INDEX_PATH, "rb") as fh:
                    html = fh.read().decode("utf-8", "replace")
            except OSError as exc:
                self._send(500, "index.html unavailable: %s\n" % exc,
                           "text/plain; charset=utf-8")
                return
            html = html.replace("__REFRESH_MS__", str(int(refresh_seconds * 1000)))
            self._send(200, html, "text/html; charset=utf-8",
                       [("Cache-Control", "no-store, no-cache, must-revalidate"),
                        ("Pragma", "no-cache")])

        def _serve_state(self):
            payload = cache.get()
            body = json.dumps(payload)
            self._send(200, body, "application/json",
                       [("Cache-Control", "no-store, no-cache, must-revalidate"),
                        ("Pragma", "no-cache"),
                        ("Expires", "0")])

    return MonitorHandler


def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="monitor/server.py",
        description="Read-only web dashboard for an agent team.")
    parser.add_argument("--project", required=True,
                        help="absolute path to the project being monitored")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--refresh", type=float, default=2.0,
                        help="browser poll interval in seconds (default 2)")
    parser.add_argument("--verbose", action="store_true",
                        help="log every HTTP request to stderr")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)

    project = os.path.abspath(os.path.expanduser(args.project))
    if not os.path.isdir(project):
        sys.stderr.write("error: --project %s is not a directory\n" % project)
        return 2
    if args.refresh <= 0:
        sys.stderr.write("error: --refresh must be greater than 0\n")
        return 2

    if args.bind not in LOCAL_BINDS:
        sys.stderr.write(
            "\n"
            "  WARNING: binding to %s exposes this dashboard on the network.\n"
            "  It has NO authentication and shows agent transcript content.\n"
            "  Bind 127.0.0.1 and reach it over an SSH tunnel instead:\n"
            "      ssh -L %d:localhost:%d %s@%s\n\n"
            % (args.bind, args.port, args.port,
               _username(), socket.gethostname()))

    cache = StateCache(project)
    handler = _build_handler(cache, args.refresh, quiet=not args.verbose)

    try:
        httpd = ThreadingHTTPServer((args.bind, args.port), handler)
    except OSError as exc:
        if exc.errno in (errno.EADDRINUSE, errno.EACCES):
            if exc.errno == errno.EADDRINUSE:
                sys.stderr.write(
                    "error: port %d is already in use on %s.\n"
                    "       Another monitor may already be running - open "
                    "http://localhost:%d/ or retry with --port %d.\n"
                    % (args.port, args.bind, args.port, args.port + 1))
            else:
                sys.stderr.write(
                    "error: not allowed to bind %s:%d (ports below 1024 need "
                    "root).\n" % (args.bind, args.port))
            return 1
        sys.stderr.write("error: could not start server on %s:%d: %s\n"
                         % (args.bind, args.port, exc))
        return 1
    httpd.daemon_threads = True

    sys.stdout.write(
        "agent-teams monitor\n"
        "  project : %s\n"
        "  serving : http://%s:%d/  (refresh %.1fs, read-only)\n"
        "  tunnel  : ssh -L %d:localhost:%d %s@%s\n"
        "  stop    : Ctrl-C\n"
        % (project, args.bind, args.port, args.refresh,
           args.port, args.port, _username(), socket.gethostname()))
    sys.stdout.flush()

    try:
        httpd.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        sys.stdout.write("\nstopped\n")
    finally:
        try:
            httpd.server_close()
        except Exception:
            pass
    return 0


def _username():
    try:
        return getpass.getuser()
    except Exception:
        return os.environ.get("USER") or "user"


if __name__ == "__main__":
    sys.exit(main())
