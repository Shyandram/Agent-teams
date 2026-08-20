#!/usr/bin/env python3
"""Pure data collection for the agent-teams monitor.

Python 3 standard library ONLY (works on 3.8+). No HTTP here, no third-party
imports, and nothing in this module may raise on bad input: every collector
degrades to empty data plus a warning string.

Produces the `GET /api/state` payload defined in docs/INTERFACES.md section 5.

Standalone use (also how the server would debug it):

    python3 collectors.py /abs/path/to/project
"""

import glob
import json
import os
import re
import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Highest priority first. See INTERFACES.md section 5.
STATE_PRECEDENCE = ["blocked", "errored", "stopped", "working", "idle", "unknown"]
_STATE_RANK = dict((s, i) for i, s in enumerate(STATE_PRECEDENCE))

# A session whose transcript has not moved in this long is not "producing".
WORKING_WINDOW_SECONDS = 90

# Only look at Codex rollouts touched this recently (keeps the scan fast).
CODEX_MAX_AGE_SECONDS = 7 * 24 * 3600

# Unmanaged Codex rollouts (no team.yaml role) are only shown if this fresh.
CODEX_ORPHAN_WINDOW_SECONDS = 30 * 60

# Transcripts reach tens of MB: only ever read the tail.
TAIL_BYTES = 256 * 1024

# Cap on stored assistant text so the API response stays small.
MAX_TEXT_CHARS = 4000

CLAUDE_TIMEOUT_SECONDS = 15

# hooks.py lives beside this file; make it importable regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _rank(state):
    return _STATE_RANK.get(state, len(STATE_PRECEDENCE))


def worst_state(*states):
    """Return the loudest (highest-precedence) state among the arguments."""
    best = "unknown"
    for s in states:
        if s and _rank(s) < _rank(best):
            best = s
    return best


def parse_ts(value):
    """Best-effort timestamp -> epoch seconds (float), or None.

    Accepts epoch milliseconds (``claude agents`` uses these), epoch seconds,
    and ISO-8601 strings. ``datetime.fromisoformat`` rejects a trailing ``Z``
    before Python 3.11, so ISO parsing is done by hand.
    """
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        v = float(value)
        if v > 1e14:          # microseconds
            return v / 1e6
        if v > 1e11:          # milliseconds (what `claude agents` emits)
            return v / 1e3
        return v
    if not isinstance(value, str):
        return None
    s = value.strip()
    if not s:
        return None
    if re.match(r"^\d+(\.\d+)?$", s):
        return parse_ts(float(s))
    m = re.match(
        r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?"
        r"\s*(Z|[+-]\d{2}:?\d{2})?$",
        s,
    )
    if not m:
        return None
    year, mon, day, hh, mm, ss = (int(m.group(i)) for i in range(1, 7))
    frac = m.group(7)
    tz = m.group(8)
    try:
        import calendar
        import datetime as _dt
        base = calendar.timegm(
            _dt.datetime(year, mon, day, hh, mm, ss).timetuple()
        )
    except Exception:
        return None
    out = float(base)
    if frac:
        out += float("0." + frac)
    if tz and tz not in ("Z", "z"):
        sign = 1 if tz[0] == "+" else -1
        digits = tz[1:].replace(":", "")
        try:
            offset = int(digits[:2]) * 3600 + int(digits[2:4]) * 60
        except Exception:
            offset = 0
        out -= sign * offset
    return out


def iso_utc(epoch):
    """Epoch seconds -> ``2026-08-20T06:30:00Z``. None-safe."""
    if epoch is None:
        return None
    try:
        return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(float(epoch)))
    except Exception:
        return None


def _mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def _pid_alive(pid):
    """True/False if we can tell, None if we cannot."""
    if not isinstance(pid, int) or pid <= 0:
        return None
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True          # exists, owned by someone else
    except Exception:
        return None


def read_tail_lines(path, nbytes=TAIL_BYTES):
    """Read the last ``nbytes`` of a file and return whole decoded lines.

    Drops the first (probably partial) line whenever the file was truncated.
    """
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            if size > nbytes:
                fh.seek(size - nbytes)
                partial = True
            else:
                partial = False
            data = fh.read()
    except OSError:
        return []
    text = data.decode("utf-8", "replace")
    lines = text.splitlines()
    if partial and lines:
        lines = lines[1:]
    return lines


def read_first_line(path, nbytes=TAIL_BYTES):
    try:
        with open(path, "rb") as fh:
            chunk = fh.read(nbytes)
    except OSError:
        return ""
    text = chunk.decode("utf-8", "replace")
    nl = text.find("\n")
    return text if nl < 0 else text[:nl]


def _clip(text):
    if not text:
        return None
    text = text.strip()
    if not text:
        return None
    if len(text) > MAX_TEXT_CHARS:
        text = text[:MAX_TEXT_CHARS] + " ..."
    return text


def _is_codex_session_id(value):
    """True only for something that could be a Codex session id.

    The launcher records `pid:<n>` for a headless Codex role, because Codex has no
    session id until its first rollout file lands. That placeholder is truthy, so a
    naive `if session_id` check made the claim path unreachable and every Codex role
    stayed unbound while its rollout showed up as an orphan.
    """
    if not value or not isinstance(value, str):
        return False
    return not value.startswith("pid:")


def project_slug(cwd):
    """Claude transcript directory name: abs cwd with '/' and '.' -> '-'."""
    return os.path.abspath(cwd).replace("/", "-").replace(".", "-")


# ---------------------------------------------------------------------------
# 1. Claude sessions  (`claude agents --json --all --cwd <project>`)
# ---------------------------------------------------------------------------

CLAUDE_FIELDS = ("id", "sessionId", "name", "status", "state", "kind",
                 "pid", "cwd", "startedAt")


def collect_claude_sessions(project, warnings=None):
    """Return a list of normalised Claude session dicts. Never raises."""
    warnings = warnings if warnings is not None else []
    try:
        proc = subprocess.Popen(
            ["claude", "agents", "--json", "--all", "--cwd", project],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        warnings.append("claude CLI not found on PATH - Claude sessions unavailable")
        return []
    except Exception as exc:
        warnings.append("could not run `claude agents`: %s" % exc)
        return []

    try:
        out, err = proc.communicate(timeout=CLAUDE_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        try:
            proc.kill()
            proc.communicate()
        except Exception:
            pass
        warnings.append("`claude agents` timed out after %ds" % CLAUDE_TIMEOUT_SECONDS)
        return []
    except Exception as exc:
        warnings.append("`claude agents` failed: %s" % exc)
        return []

    if proc.returncode != 0:
        detail = (err or b"").decode("utf-8", "replace").strip().splitlines()
        detail = detail[-1] if detail else "no stderr"
        warnings.append("`claude agents` exited %s: %s" % (proc.returncode, detail[:200]))
        return []

    raw = (out or b"").decode("utf-8", "replace").strip()
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except ValueError:
        warnings.append("`claude agents` returned unparseable JSON")
        return []
    if isinstance(parsed, dict):
        parsed = parsed.get("agents") or parsed.get("sessions") or []
    if not isinstance(parsed, list):
        warnings.append("`claude agents` returned an unexpected JSON shape")
        return []

    sessions = []
    for item in parsed:
        if not isinstance(item, dict):
            continue
        rec = dict((k, item.get(k)) for k in CLAUDE_FIELDS)
        rec["started_at_epoch"] = parse_ts(item.get("startedAt"))
        rec["runtime"] = "claude-code"
        sessions.append(rec)
    return sessions


# ---------------------------------------------------------------------------
# 2. Claude transcript content
# ---------------------------------------------------------------------------

def transcript_path(cwd, session_id, home=None):
    """Locate a session transcript.

    A background agent may relocate itself into a git worktree (it calls
    EnterWorktree on its own), and its transcript then lives under the WORKTREE's
    slug directory, not the project's -- e.g.

        -Users-me-proj                                   (project)
        -Users-me-proj--claude-worktrees-merry-magpie    (where it actually writes)

    Verified behaviour. Checking only the project slug silently loses the content of
    every worktree-based agent, so fall back to a glob over sibling worktree dirs.
    """
    if not cwd or not session_id:
        return None
    home = home or os.path.expanduser("~")
    root = os.path.join(home, ".claude", "projects")
    slug = project_slug(cwd)

    direct = os.path.join(root, slug, "%s.jsonl" % session_id)
    if os.path.exists(direct):
        return direct

    try:
        matches = glob.glob(os.path.join(root, slug + "--claude-worktrees-*",
                                         "%s.jsonl" % session_id))
    except Exception:
        matches = []
    if matches:
        return matches[0]

    # Last resort: the session may have moved somewhere unrelated. A whole-tree glob
    # is bounded by one directory level and only runs when the first two paths miss.
    try:
        anywhere = glob.glob(os.path.join(root, "*", "%s.jsonl" % session_id))
    except Exception:
        anywhere = []
    if anywhere:
        return anywhere[0]

    return direct  # canonical path, for the caller's "missing" reporting


def collect_claude_transcript(cwd, session_id, warnings=None, home=None):
    """Last assistant text + mtime for one Claude session.

    Reads only the tail of the JSONL - these files reach tens of MB.
    """
    warnings = warnings if warnings is not None else []
    result = {"path": None, "last_text": None, "last_activity": None}
    path = transcript_path(cwd, session_id, home=home)
    if not path:
        return result
    result["path"] = path
    if not os.path.exists(path):
        return result
    result["last_activity"] = _mtime(path)

    last_text = None
    tok_in = tok_out = tok_cache = 0
    model_seen = None
    for line in read_tail_lines(path):
        line = line.strip()
        if not line or line[0] != "{":
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        if not isinstance(rec, dict) or rec.get("type") != "assistant":
            continue
        message = rec.get("message")
        if not isinstance(message, dict):
            continue
        # Token accounting: the transcript carries per-message usage, so cost is
        # observable without any extra API call.
        usage = message.get("usage")
        if isinstance(usage, dict):
            tok_in += usage.get("input_tokens") or 0
            tok_out += usage.get("output_tokens") or 0
            tok_cache += usage.get("cache_read_input_tokens") or 0
        if message.get("model"):
            model_seen = message.get("model")
        content = message.get("content")
        if isinstance(content, str):
            last_text = content
            continue
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text")
                if isinstance(text, str) and text.strip():
                    last_text = text
    result["last_text"] = _clip(last_text)
    result["tokens_in"] = tok_in
    result["tokens_out"] = tok_out
    result["tokens_cache_read"] = tok_cache
    result["model"] = model_seen
    result["result_block"] = extract_result_block(last_text)
    return result


RESULT_RE = re.compile(
    r"<result>\s*(.*?)\s*</result>|```result\s*\n(.*?)\n```",
    re.DOTALL | re.IGNORECASE,
)


def extract_result_block(text):
    """Pull a role's declared deliverable out of its last message.

    Roles are asked to wrap their outcome in <result>...</result>. Surfacing that
    instead of a raw transcript tail is what lets the lead read summaries rather
    than transcripts. Returns None when the role has not declared one.
    """
    if not text:
        return None
    matches = RESULT_RE.findall(text)
    if not matches:
        return None
    last = matches[-1]
    block = last[0] or last[1]
    block = (block or "").strip()
    return block[:MAX_TEXT_CHARS] if block else None


# ---------------------------------------------------------------------------
# 3. Codex sessions  (~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl)
# ---------------------------------------------------------------------------

# Rollout files carry the interesting type in payload.type; the bare top-level
# error/turn.failed types come from `codex --json` on stdout. Check both.
_CODEX_ERROR_TYPES = ("error", "turn.failed", "turn_failed", "stream_error")


def _codex_error_message(rec):
    payload = rec.get("payload") if isinstance(rec.get("payload"), dict) else {}
    for source in (payload, rec):
        msg = source.get("message")
        if isinstance(msg, str) and msg.strip():
            return msg.strip()
        err = source.get("error")
        if isinstance(err, dict):
            msg = err.get("message")
            if isinstance(msg, str) and msg.strip():
                return msg.strip()
        if isinstance(err, str) and err.strip():
            return err.strip()
    return "codex reported an error"


def collect_codex_sessions(project, warnings=None, home=None,
                           max_age=CODEX_MAX_AGE_SECONDS):
    """Codex rollouts whose session_meta cwd is inside ``project``."""
    warnings = warnings if warnings is not None else []
    home = home or os.path.expanduser("~")
    root = os.path.join(home, ".codex", "sessions")
    if not os.path.isdir(root):
        return []

    project_abs = os.path.abspath(project)
    now = time.time()
    try:
        candidates = glob.glob(os.path.join(root, "*", "*", "*", "rollout-*.jsonl"))
    except Exception as exc:
        warnings.append("could not scan Codex sessions: %s" % exc)
        return []

    out = []
    for path in candidates:
        mtime = _mtime(path)
        if mtime is None or (now - mtime) > max_age:
            continue                                   # keep the scan cheap
        head = read_first_line(path).strip()
        if not head or head[0] != "{":
            continue
        try:
            meta = json.loads(head)
        except ValueError:
            continue
        if not isinstance(meta, dict) or meta.get("type") != "session_meta":
            continue
        payload = meta.get("payload")
        if not isinstance(payload, dict):
            continue
        cwd = payload.get("cwd")
        if not isinstance(cwd, str):
            continue
        cwd_abs = os.path.abspath(cwd)
        if cwd_abs != project_abs and not cwd_abs.startswith(project_abs + os.sep):
            continue

        session_id = payload.get("session_id") or payload.get("id")
        rec = {
            "runtime": "codex",
            "path": path,
            "session_id": session_id,
            "cwd": cwd_abs,
            "last_activity": mtime,
            "started_at_epoch": parse_ts(payload.get("timestamp")
                                         or meta.get("timestamp")),
            "error": None,
            "last_text": None,
        }
        _scan_codex_tail(path, rec)
        out.append(rec)

    out.sort(key=lambda r: r.get("last_activity") or 0, reverse=True)
    return out


def _scan_codex_tail(path, rec):
    """Fill in last agent message and any terminal error from the tail."""
    last_text = None
    error = None
    for line in read_tail_lines(path):
        line = line.strip()
        if not line or line[0] != "{":
            continue
        try:
            item = json.loads(line)
        except ValueError:
            continue
        if not isinstance(item, dict):
            continue
        payload = item.get("payload") if isinstance(item.get("payload"), dict) else {}
        types = (item.get("type"), payload.get("type"))
        if any(t in _CODEX_ERROR_TYPES for t in types if isinstance(t, str)):
            error = _codex_error_message(item)
            continue
        if payload.get("type") == "agent_message":
            msg = payload.get("message")
            if isinstance(msg, str) and msg.strip():
                last_text = msg
        elif payload.get("type") == "task_complete":
            msg = payload.get("last_agent_message")
            if isinstance(msg, str) and msg.strip():
                last_text = msg
        elif item.get("type") == "response_item" and payload.get("type") == "message":
            content = payload.get("content")
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict):
                        text = block.get("text")
                        if isinstance(text, str) and text.strip():
                            last_text = text
    rec["last_text"] = _clip(last_text)
    rec["error"] = _clip(error)
    return rec


# ---------------------------------------------------------------------------
# 4. Coordination notes  (docs/coordination/*.md)
# ---------------------------------------------------------------------------

_SKIP_NOTES = ("README.md", "_template.md")


def parse_frontmatter(text):
    """Line-based '---' frontmatter parse. No YAML library, by design."""
    out = {}
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return out
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            break
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            out[key] = value
    return out


def collect_coordination_notes(project, warnings=None):
    """Return note dicts with session_id / role / status from frontmatter."""
    warnings = warnings if warnings is not None else []
    directory = os.path.join(project, "docs", "coordination")
    if not os.path.isdir(directory):
        return []
    notes = []
    try:
        paths = sorted(glob.glob(os.path.join(directory, "*.md")))
    except Exception as exc:
        warnings.append("could not list coordination notes: %s" % exc)
        return []
    for path in paths:
        if os.path.basename(path) in _SKIP_NOTES:
            continue
        try:
            with open(path, "rb") as fh:
                head = fh.read(8192).decode("utf-8", "replace")
        except OSError:
            continue
        fm = parse_frontmatter(head)
        if not fm:
            continue
        notes.append({
            "path": path,
            "file": os.path.basename(path),
            "session_id": fm.get("session_id") or None,
            "role": fm.get("role") or None,
            "status": fm.get("status") or None,
            "updated": _mtime(path),
        })
    return notes


# ---------------------------------------------------------------------------
# 5. Team manifest + session state
# ---------------------------------------------------------------------------

def parse_team_yaml(text):
    """Naive team.yaml reader per INTERFACES.md section 2.

    Top-level ``key: value`` one per line; ``roles:`` holds two-space indented
    ``- name: x`` items whose following four-space lines are that role's keys.
    """
    data = {"roles": []}
    current = None
    in_roles = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.strip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent == 0:
            in_roles = False
            current = None
            if stripped == "roles:" or stripped.startswith("roles:"):
                in_roles = True
                continue
            if ":" in stripped:
                key, _, value = stripped.partition(":")
                value = value.strip().strip('"').strip("'")
                if value:
                    data[key.strip()] = value
            continue

        if not in_roles:
            continue

        if stripped.startswith("- "):
            entry = stripped[2:].strip()
            current = {}
            data["roles"].append(current)
            if ":" in entry:
                key, _, value = entry.partition(":")
                current[key.strip()] = value.strip().strip('"').strip("'")
        elif current is not None and ":" in stripped:
            key, _, value = stripped.partition(":")
            current[key.strip()] = value.strip().strip('"').strip("'")
    return data


def collect_team_manifest(project, warnings=None):
    warnings = warnings if warnings is not None else []
    path = os.path.join(project, ".agent-teams", "team.yaml")
    if not os.path.exists(path):
        warnings.append("no .agent-teams/team.yaml in this project "
                        "- showing live sessions only")
        return {"roles": []}
    try:
        with open(path, "rb") as fh:
            text = fh.read().decode("utf-8", "replace")
    except OSError as exc:
        warnings.append("could not read team.yaml: %s" % exc)
        return {"roles": []}
    try:
        return parse_team_yaml(text)
    except Exception as exc:
        warnings.append("could not parse team.yaml: %s" % exc)
        return {"roles": []}


def collect_session_files(project, warnings=None):
    warnings = warnings if warnings is not None else []
    directory = os.path.join(project, ".agent-teams", "sessions")
    if not os.path.isdir(directory):
        return []
    out = []
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        try:
            with open(path, "rb") as fh:
                data = json.loads(fh.read().decode("utf-8", "replace"))
        except (OSError, ValueError) as exc:
            warnings.append("bad session file %s: %s"
                            % (os.path.basename(path), exc))
            continue
        if not isinstance(data, dict):
            continue
        data.setdefault("role", os.path.splitext(os.path.basename(path))[0])
        data["_path"] = path
        out.append(data)
    return out


# ---------------------------------------------------------------------------
# Merge -> /api/state
# ---------------------------------------------------------------------------

# Observed `claude agents` state values: working, blocked, stopped, done.
# Observed status values: busy, idle, waiting, null.
_CLAUDE_STOPPED_STATES = ("stopped", "done", "completed", "finished", "exited",
                          "cancelled", "canceled", "killed")
_CLAUDE_ERROR_STATES = ("error", "errored", "failed")


def _claude_state(agent, warnings=None):
    """Map a `claude agents` record to our state vocabulary.

    Unrecognised values become `unknown` **and** raise a warning rather than
    being guessed at - the dashboard must not invent a state.
    """
    state = (agent.get("state") or "").lower() or None
    status = (agent.get("status") or "").lower() or None

    # status:"waiting" + state:"blocked" = sitting on a permission prompt.
    if status == "waiting" or state == "blocked":
        return "blocked"
    if state in _CLAUDE_ERROR_STATES:
        return "errored"
    if state in _CLAUDE_STOPPED_STATES:
        return "stopped"
    if state == "working":
        # `state:"working"` with `status:"idle"` means alive but not producing.
        return "idle" if status == "idle" else "working"
    if state == "idle":
        return "idle"
    if state is None:
        if status == "busy":
            return "working"
        if status == "idle":
            return "idle"
    elif warnings is not None:
        warnings.append(
            "unrecognised claude state %r (status %r) for session %s - shown as unknown"
            % (state, status, agent.get("id")))
    return "unknown"


def _codex_state(rollout, pid):
    if rollout is None:
        return "unknown"
    if rollout.get("error"):
        return "errored"
    alive = _pid_alive(pid)
    fresh = False
    last = rollout.get("last_activity")
    if last is not None:
        fresh = (time.time() - last) <= WORKING_WINDOW_SECONDS
    if alive is False:
        return "stopped"
    if fresh:
        return "working"
    if alive is True:
        return "idle"
    return "stopped"


def _short(sid):
    if not isinstance(sid, str):
        return None
    return sid.split("-")[0] if "-" in sid else sid


def _note_for(notes, role, session_ids):
    ids = set(i for i in session_ids if i)
    ids |= set(_short(i) for i in ids if i)
    best = None
    for note in notes:
        nid = note.get("session_id")
        if nid and (nid in ids or _short(nid) in ids):
            if best is None or (note.get("updated") or 0) > (best.get("updated") or 0):
                best = note
    if best is not None:
        return best
    for note in notes:
        if role and note.get("role") == role:
            if best is None or (note.get("updated") or 0) > (best.get("updated") or 0):
                best = note
    return best


def _row(role, runtime, layout):
    return {
        "role": role,
        "runtime": runtime,
        "layout": layout,
        "state": "unknown",
        "status": None,
        "pid": None,
        "session_id": None,
        "idle_seconds": None,
        "last_activity": None,
        "last_text": None,
        "note_status": None,
        "error": None,
        # Additive, monitor-only: false means the session is live in this
        # project but is not declared in team.yaml.
        "managed": True,
        "name": None,
        "cwd": None,
        "started_at": None,
    }


def collect_state(project, home=None):
    """Build the full `GET /api/state` document. Never raises."""
    warnings = []
    project = os.path.abspath(os.path.expanduser(project))
    now = time.time()

    manifest = collect_team_manifest(project, warnings)
    session_files = collect_session_files(project, warnings)
    agents = collect_claude_sessions(project, warnings)
    rollouts = collect_codex_sessions(project, warnings, home=home)
    notes = collect_coordination_notes(project, warnings)

    used_agents = set()
    used_rollouts = set()
    rows = []

    manifest_roles = [r for r in manifest.get("roles", []) if r.get("name")]
    by_role_file = {}
    for sf in session_files:
        by_role_file.setdefault(sf.get("role"), sf)

    ordered = []
    seen_roles = set()
    for entry in manifest_roles:
        ordered.append((entry.get("name"), entry, by_role_file.get(entry.get("name"))))
        seen_roles.add(entry.get("name"))
    for sf in session_files:                      # session without a manifest row
        if sf.get("role") not in seen_roles:
            seen_roles.add(sf.get("role"))
            ordered.append((sf.get("role"), {}, sf))

    default_runtime = manifest.get("default_runtime") or "claude-code"

    for role, entry, sf in ordered:
        sf = sf or {}
        runtime = sf.get("runtime") or entry.get("runtime") or default_runtime
        row = _row(role, runtime, sf.get("layout"))
        row["pid"] = sf.get("pid") if isinstance(sf.get("pid"), int) else None
        short_id = sf.get("session_id")
        full_id = sf.get("full_session_id")
        row["session_id"] = short_id or _short(full_id)
        row["started_at"] = iso_utc(parse_ts(sf.get("started_at")))
        row["cwd"] = sf.get("cwd") or project

        states = []
        last_activity = None

        if runtime == "codex":
            # A `pid:` placeholder is not a Codex session id; treat it as absent.
            cx_short = short_id if _is_codex_session_id(short_id) else None
            cx_full = full_id if _is_codex_session_id(full_id) else None

            rollout = None
            for idx, r in enumerate(rollouts):
                if idx in used_rollouts:
                    continue
                rid = r.get("session_id")
                if rid and (rid == cx_full or _short(rid) == (cx_short or cx_full)):
                    rollout = r
                    used_rollouts.add(idx)
                    break
            if rollout is None and not (cx_short or cx_full):
                # Codex roles have no session id until the first rollout lands
                # (INTERFACES s3). Claim the freshest unclaimed rollout for
                # this project that started after the role did.
                # Claim the unclaimed rollout for this project whose start is CLOSEST
                # to the role's. A hard "must have started after the role" cutoff was
                # too brittle: the rollout timestamp and the session file's timestamp
                # come from different clocks and different moments, and a rollout that
                # appeared slightly early left the role permanently unbound while its
                # own output showed up as an orphan.
                started = parse_ts(sf.get("started_at"))
                best = None
                for idx, r in enumerate(rollouts):
                    if idx in used_rollouts:
                        continue
                    r_start = r.get("started_at_epoch") or r.get("last_activity")
                    if started and r_start:
                        delta = abs(r_start - started)
                    else:
                        delta = float("inf")
                    if best is None or delta < best[0]:
                        best = (delta, idx, r)
                if best is not None:
                    rollout = best[2]
                    used_rollouts.add(best[1])
            if rollout is not None:
                row["session_id"] = _short(rollout.get("session_id")) or row["session_id"]
                row["last_text"] = rollout.get("last_text")
                row["result_block"] = extract_result_block(rollout.get("last_text"))
                row["error"] = rollout.get("error")
                last_activity = rollout.get("last_activity")
                states.append(_codex_state(rollout, row["pid"]))
                if rollout.get("error"):
                    warnings.append("codex error for role %s: %s"
                                    % (role, (rollout["error"] or "")[:160]))
            elif sf:
                states.append("stopped" if _pid_alive(row["pid"]) is False else "unknown")
        else:
            agent = None
            for idx, a in enumerate(agents):
                if idx in used_agents:
                    continue
                if full_id and a.get("sessionId") == full_id:
                    agent = a
                elif short_id and a.get("id") == short_id:
                    agent = a
                elif short_id and a.get("sessionId") == short_id:
                    agent = a
                elif short_id and _short(a.get("sessionId")) == short_id:
                    agent = a
                if agent is not None:
                    used_agents.add(idx)
                    break
            if agent is None:
                # Fall back to the display name the launcher assigns ("at:<role>").
                # Without this, a role's own sessions surface as unmanaged orphans
                # sitting next to the role they belong to -- the same agent listed
                # twice, which makes the dashboard actively misleading.
                best = None
                for idx, a in enumerate(agents):
                    if idx in used_agents:
                        continue
                    if (a.get("name") or "") != "at:%s" % role:
                        continue
                    # Prefer the liveliest, then the most recently started.
                    key = (0 if (a.get("state") or "") not in
                           ("stopped", "done", "completed", "finished", "exited")
                           else 1,
                           -(a.get("started_at_epoch") or 0))
                    if best is None or key < best[0]:
                        best = (key, idx, a)
                if best is not None:
                    used_agents.add(best[1])
                    agent = best[2]
            if agent is not None:
                row["status"] = agent.get("status")
                row["name"] = agent.get("name")
                row["pid"] = agent.get("pid") if isinstance(agent.get("pid"), int) else row["pid"]
                row["session_id"] = agent.get("id") or row["session_id"]
                row["cwd"] = agent.get("cwd") or row["cwd"]
                row["started_at"] = iso_utc(agent.get("started_at_epoch")) or row["started_at"]
                states.append(_claude_state(agent, warnings))
                tr = collect_claude_transcript(agent.get("cwd") or project,
                                               agent.get("sessionId"),
                                               warnings, home=home)
                row["last_text"] = tr.get("last_text")
                row["result_block"] = tr.get("result_block")
                row["tokens_total"] = (tr.get("tokens_in") or 0) + (tr.get("tokens_out") or 0)
                row["tokens_cache_read"] = tr.get("tokens_cache_read") or 0
                row["model"] = tr.get("model")
                last_activity = tr.get("last_activity")
            elif sf:
                tr = collect_claude_transcript(sf.get("cwd") or project, full_id,
                                               warnings, home=home)
                row["last_text"] = tr.get("last_text")
                row["result_block"] = tr.get("result_block")
                row["tokens_total"] = (tr.get("tokens_in") or 0) + (tr.get("tokens_out") or 0)
                row["tokens_cache_read"] = tr.get("tokens_cache_read") or 0
                row["model"] = tr.get("model")
                last_activity = tr.get("last_activity")
                states.append("stopped")

        if not states:
            states.append("unknown")
        row["state"] = worst_state(*states)
        if row["state"] == "unknown" and not sf:
            row["state"] = "unknown"

        note = _note_for(notes, role, [short_id, full_id, row["session_id"]])
        if note:
            row["note_status"] = note.get("status")
            if note.get("updated") and (last_activity is None
                                        or note["updated"] > last_activity):
                pass  # note freshness never counts as agent activity

        row["last_activity"] = iso_utc(last_activity)
        row["idle_seconds"] = int(max(0, now - last_activity)) if last_activity else None
        rows.append(row)

    # Unmanaged but live sessions in this project. Hiding a blocked agent just
    # because it is not in team.yaml would be a lie by omission.
    for idx, agent in enumerate(agents):
        if idx in used_agents:
            continue
        row = _row(agent.get("name") or agent.get("id") or "claude", "claude-code", None)
        row["managed"] = False
        row["name"] = agent.get("name")
        row["status"] = agent.get("status")
        row["pid"] = agent.get("pid") if isinstance(agent.get("pid"), int) else None
        row["session_id"] = agent.get("id")
        row["cwd"] = agent.get("cwd")
        row["started_at"] = iso_utc(agent.get("started_at_epoch"))
        row["state"] = _claude_state(agent, warnings)
        tr = collect_claude_transcript(agent.get("cwd") or project,
                                       agent.get("sessionId"), warnings, home=home)
        row["last_text"] = tr.get("last_text")
        last_activity = tr.get("last_activity")
        row["last_activity"] = iso_utc(last_activity)
        row["idle_seconds"] = int(max(0, now - last_activity)) if last_activity else None
        note = _note_for(notes, None, [agent.get("id"), agent.get("sessionId")])
        if note:
            row["note_status"] = note.get("status")
        rows.append(row)

    for idx, rollout in enumerate(rollouts):
        if idx in used_rollouts:
            continue
        last = rollout.get("last_activity") or 0
        if (now - last) > CODEX_ORPHAN_WINDOW_SECONDS and not rollout.get("error"):
            continue
        sid = _short(rollout.get("session_id")) or "codex"
        row = _row("codex:%s" % sid, "codex", None)
        row["managed"] = False
        row["session_id"] = sid
        row["cwd"] = rollout.get("cwd")
        row["started_at"] = iso_utc(rollout.get("started_at_epoch"))
        row["last_text"] = rollout.get("last_text")
        row["error"] = rollout.get("error")
        row["state"] = _codex_state(rollout, None)
        row["last_activity"] = iso_utc(last or None)
        row["idle_seconds"] = int(max(0, now - last)) if last else None
        rows.append(row)

    rows.sort(key=lambda r: (_rank(r.get("state")), 0 if r.get("managed") else 1,
                             r.get("role") or ""))

    # Turn observed states into action. A dashboard nobody is watching is not
    # observability; hooks are what make an unattended fleet safe to leave alone.
    # Fired before the payload is returned so a warning from a failed hook is
    # visible in the same response, and never allowed to break collection.
    try:
        import hooks as _hooks
        _hooks.fire(os.path.abspath(project), rows, warnings)
    except Exception as exc:
        warnings.append("hooks unavailable: %s" % exc)

    return {
        "project": project,
        "project_name": manifest.get("project_name") or os.path.basename(project),
        "generated_at": iso_utc(now),
        "roles": rows,
        "warnings": warnings,
    }


# ---------------------------------------------------------------------------

STATE_GLYPH = {
    "blocked": "!",
    "errored": "x",
    "stopped": ".",
    "working": ">",
    "idle": "-",
    "unknown": "?",
}


def render_table(state):
    """Human-readable snapshot for `agent-teams status`."""
    out = []
    roles = state.get("roles") or []
    out.append("")
    out.append("  %s  (%s)" % (state.get("project_name") or "?", state.get("project") or "?"))
    out.append("")

    if not roles:
        out.append("  no roles found — run: agent-teams init")
    else:
        out.append("  %-1s %-16s %-13s %-7s %-9s %8s %10s  %s"
                   % ("", "ROLE", "RUNTIME", "LAYOUT", "STATE", "IDLE", "TOKENS", "LAST"))
        out.append("  " + "-" * 100)
        for r in roles:
            idle = r.get("idle_seconds")
            if idle is None:
                idle_s = "-"
            elif idle < 60:
                idle_s = "%ds" % int(idle)
            elif idle < 3600:
                idle_s = "%dm" % int(idle // 60)
            else:
                idle_s = "%dh" % int(idle // 3600)
            last = (r.get("result_block") or r.get("last_text")
                    or r.get("error") or "")
            last = " ".join(last.split())
            if len(last) > 38:
                last = last[:37] + "…"
            st = r.get("state") or "unknown"
            tok = r.get("tokens_total") or 0
            tok_s = format(tok, ",") if tok else "-"
            out.append("  %-1s %-16s %-13s %-7s %-9s %8s %10s  %s"
                       % (STATE_GLYPH.get(st, "?"), r.get("role") or "?",
                          r.get("runtime") or "-", r.get("layout") or "-",
                          st, idle_s, tok_s, last))

        blocked = [r for r in roles if r.get("state") == "blocked"]
        errored = [r for r in roles if r.get("state") == "errored"]
        out.append("")
        if blocked:
            out.append("  ! %d role(s) BLOCKED on a permission prompt — they will not"
                       " progress until a human acts:" % len(blocked))
            for r in blocked:
                out.append("      %s" % (r.get("role") or "?"))
        if errored:
            out.append("  x %d role(s) errored:" % len(errored))
            for r in errored:
                out.append("      %-16s %s" % (r.get("role") or "?",
                                               (r.get("error") or "")[:60]))
        if not blocked and not errored:
            live = [r for r in roles if r.get("state") in ("working", "idle")]
            unknown = [r for r in roles if r.get("state") == "unknown"]
            if live:
                msg = "  %d role(s) running" % len(live)
                if unknown:
                    msg += ", %d not started" % len(unknown)
                out.append(msg)
            elif unknown:
                out.append("  nothing running — %d role(s) declared but not started"
                           " (run: agent-teams launch)" % len(unknown))
            else:
                out.append("  no active roles")

    for w in state.get("warnings") or []:
        out.append("  warning: %s" % w)
    out.append("")
    return "\n".join(out)


def main(argv):
    args = argv[1:]
    project = None
    as_json = False
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--project", "-C") and i + 1 < len(args):
            project = args[i + 1]; i += 2; continue
        if a == "--json":
            as_json = True; i += 1; continue
        if a in ("-h", "--help"):
            sys.stdout.write(
                "usage: collectors.py [--project PATH] [--json]\n"
                "  Collects the state of every agent-teams role in a project.\n")
            return 0
        if not a.startswith("-") and project is None:
            project = a; i += 1; continue
        i += 1
    if project is None:
        project = os.getcwd()

    try:
        state = collect_state(project)
    except Exception as exc:  # collectors must never take the server down
        state = {
            "project": os.path.abspath(project),
            "project_name": os.path.basename(os.path.abspath(project)),
            "generated_at": iso_utc(time.time()),
            "roles": [],
            "warnings": ["collector failure: %s" % exc],
        }

    if as_json:
        json.dump(state, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        sys.stdout.write(render_table(state) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
