#!/usr/bin/env bash
set -euo pipefail

# defectdojo-configure.sh — the one idempotent DefectDojo System Settings
# bootstrap per install (Phase 28, D-10; ADR-026). Run it once after a fresh
# install; a rerun reads the settings, finds nothing drifted and changes
# nothing.
#
# WHY THIS EXISTS. Deduplication is OFF on a fresh DefectDojo 3.3.200 install
# (enable_deduplication defaults False). Without this bootstrap the chart's
# dedup guards (D-20) and the per-parser algorithm map are inert and every
# reimport of a branch piles up duplicates (DDOJO-03).
#
# WHICH TOKEN. /api/v2/system_settings/ is superuser-only (IsSuperUser), so
# this script takes an OPERATOR-HELD SUPERUSER token from a file. It is NEVER
# the CI DEFECTDOJO_API_TOKEN (the staff, non-superuser ci-importer of 27 D-10)
# and it is never stored as a GitHub secret. That split is deliberate: CI keeps
# its least-privilege importer, and the one-off settings change is done by an
# operator. It is not a regression of 27 D-10.
#
# DESIRED STATE (exactly these five keys, nothing else is ever sent):
#   enable_deduplication               = true   (D-10, DDOJO-03)
#   delete_duplicates                  = false  (D-04: duplicates are kept and
#                                                marked, never deleted)
#   false_positive_history             = false  (the API does not refuse FP
#   retroactive_false_positive_history = false   history together with dedup,
#                                                so both are pinned off)
#   risk_acceptance_form_default_days  = 90     (D-22)
# enable_finding_sla is deliberately NOT read-to-write and NOT sent (D-21): SLA
# is not part of triage (D-16), so its upstream value is left untouched.
#
# The script only PATCHes the keys that drifted, to /api/v2/system_settings/<id>/
# using the id the GET returned, then re-GETs and verifies. It prints a line
# starting "NO CHANGE" when nothing drifted and "CHANGED:" plus the key list
# otherwise. It does not change .github/workflows/security.yml.
#
# TLS (ADR-025): DEFECTDOJO_URL must be https://, checked before the token file
# is read or any request is made. Every curl is pinned to https with --proto and
# --proto-redir. TLS is always verified; there is no option to switch it off.
# DEFECTDOJO_CA_FILE (optional) adds --cacert for a private CA.
#
# CURL CONFIG (ADR-029, Phase 28 CR-01). Every curl passes -q as its first
# argument, so no curlrc (~/.curlrc, $CURL_HOME/.curlrc, $XDG_CONFIG_HOME/curlrc)
# is read: an operator curlrc with "insecure" or "cacert" cannot switch
# verification off or swap the trust anchor. Each request must end with curl
# exit 0 AND ssl_verify_result 0 before its HTTP code is even looked at;
# otherwise the script stops with "TLS verification result". curl stderr is
# discarded and never printed; a failure line carries only the method, path,
# curl exit, HTTP code, verify result and curl's %{errormsg}.
#
# The token is read from a file (never argv, never echoed), written only to a
# 0600 header file (O_EXCL) in a private temp dir, sent with -H @file, and the
# temp dir is removed before exit. xtrace is never enabled in this script.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   DEFECTDOJO_URL=https://defectdojo.example.com \
#   DEFECTDOJO_ADMIN_TOKEN_FILE=/path/to/token \
#     bash scripts/defectdojo-configure.sh
# Optional: DEFECTDOJO_CA_FILE=/path/to/ca.pem
# Test hook: DEFECTDOJO_RESOLVE=host:port:IPv4 is set only by
# scripts/defectdojo-import-proof.sh (passed to curl as one --resolve). Leave it
# unset in real use. When set it must be host:port:IPv4 with the host and port
# of DEFECTDOJO_URL, else exit 2.
# DEFECTDOJO_ADMIN_TOKEN_FILE must be a regular file, not readable by group or
# other (chmod 600), holding one BARE DefectDojo API token: 40 lowercase hex
# characters on one line, no "Token " prefix (a single trailing newline is fine).
#
# Exit codes:
#   0  the settings match (NO CHANGE, or CHANGED and verified)
#   1  refusal (non-https URL), a transport failure (curl exit not 0 or TLS
#      verification result not 0), or an API / settings verification failure
#   2  preflight failure: an argument was given, a required env var or binary
#      is missing, DEFECTDOJO_RESOLVE is malformed or does not match
#      DEFECTDOJO_URL, the token file is missing, not a regular file,
#      group/other-readable, unreadable or not one bare 40-hex token, or the
#      CA file is missing

usage() {
  echo "usage: DEFECTDOJO_URL=https://... DEFECTDOJO_ADMIN_TOKEN_FILE=<file> [DEFECTDOJO_CA_FILE=<file>] bash scripts/defectdojo-configure.sh" >&2
  exit 2
}

require_bins() {
  local bin
  for bin in "$@"; do
    if ! command -v "$bin" &>/dev/null; then
      echo "FATAL: required binary '${bin}' not found on PATH" >&2
      exit 2
    fi
  done
}

[ "$#" -eq 0 ] || usage
require_bins curl python3

for v in DEFECTDOJO_URL DEFECTDOJO_ADMIN_TOKEN_FILE; do
  if [ -z "${!v:-}" ]; then
    echo "FATAL: ${v} is not set (see the usage lines at the top of this script)" >&2
    exit 2
  fi
done

umask 077

python3 - <<'PY'
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import urllib.parse

env = os.environ
url = env.get("DEFECTDOJO_URL", "").rstrip("/")
token_file = env.get("DEFECTDOJO_ADMIN_TOKEN_FILE", "")
ca_file = env.get("DEFECTDOJO_CA_FILE", "")
# Test hook: set only by scripts/defectdojo-import-proof.sh; validated in main().
resolve = env.get("DEFECTDOJO_RESOLVE", "")
RESOLVE_RE = re.compile(r"^([A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?):([0-9]{1,5}):((?:[0-9]{1,3}\.){3}[0-9]{1,3})$")
TOKEN_RE = re.compile(r"[0-9a-f]{40}")

DESIRED = {
    "enable_deduplication": True,
    "delete_duplicates": False,
    "false_positive_history": False,
    "retroactive_false_positive_history": False,
    "risk_acceptance_form_default_days": 90,
}

tmpdir = tempfile.mkdtemp()
hdr_path = os.path.join(tmpdir, "auth-header")
body_path = os.path.join(tmpdir, "patch-body.json")
resp_path = os.path.join(tmpdir, "response.json")


class Failed(Exception):
    pass


class Preflight(Exception):
    pass


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(text)


def api(tls_args, method, path, expect, body=None):
    # -q MUST stay argv[1]: it stops curl reading any curlrc (ADR-029, Phase 28 CR-01).
    cmd = ["curl", "-q", "-sS", "--proto", "=https", "--proto-redir", "=https", "-X", method, "-o", resp_path,
           "-w", "%{http_code} %{ssl_verify_result} %{errormsg}"] + tls_args
    if resolve:
        cmd += ["--resolve", resolve]
    cmd += ["-H", "@" + hdr_path]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "--data-binary", "@" + body]
    cmd += [url + path]
    # curl stderr is discarded, never read or printed (it can carry verbose/trace output).
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          universal_newlines=True)
    # %{errormsg} is last because it may contain spaces.
    code, verify, errmsg = ((proc.stdout or "").strip().split(" ", 2) + ["", "", ""])[:3]
    code = code or "000"
    text = ""
    if os.path.isfile(resp_path):
        with open(resp_path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        os.remove(resp_path)
    # Transport first: the curl exit is tested before the verify result, because
    # ssl_verify_result reads "0" on a refused connection.
    if proc.returncode != 0 or verify != "0":
        print("FAILED: {} {}: curl exit {}, http {}, TLS verification result {} (must be 0): {}".format(
            method, path, proc.returncode, code, verify or "none", errmsg or "no error message"))
        raise Failed()
    if code != expect:
        # Only the DefectDojo response body of a verified transfer is shown.
        detail = text[:500] if text else "(empty)"
        print("FAILED: {} {} http={} body={}".format(method, path, code, detail))
        raise Failed()
    try:
        return json.loads(text)
    except ValueError:
        print("FAILED: {} {} http={} but the body is not JSON: {}".format(method, path, code, text[:500]))
        raise Failed()


def read_settings(tls_args):
    path = "/api/v2/system_settings/"
    data = api(tls_args, "GET", path, "200")
    rows = data.get("results") if isinstance(data, dict) else None
    if (not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict)
            or not isinstance(rows[0].get("id"), int) or isinstance(rows[0].get("id"), bool)):
        print("FAILED: GET {} http=200 but expected a results list of exactly one object with an integer id: {}".format(
            path, json.dumps(data)[:500]))
        raise Failed()
    return rows[0]


def drifted(row):
    return [k for k, v in DESIRED.items() if k not in row or row.get(k) != v or type(row.get(k)) is not type(v)]


def main():
    # ADR-025: refuse a non-https URL before the token file is read and before any request.
    if not url.lower().startswith("https://"):
        print("FAILED: DEFECTDOJO_URL must be https:// — refusing to send the admin token over {!r}".format(
            url.split("://", 1)[0] if "://" in url else "(no scheme)"))
        raise Failed()

    # Test hook (after the https refusal, before the token file is read).
    if resolve:
        match = RESOLVE_RE.fullmatch(resolve)
        ok = False
        if match:
            parts = urllib.parse.urlsplit(url)
            try:
                url_port = parts.port or 443
            except ValueError:
                url_port = None
            ok = (url_port is not None and match.group(1).lower() == (parts.hostname or "")
                  and int(match.group(2)) == url_port)
        if not ok:
            print("FATAL: DEFECTDOJO_RESOLVE must be host:port:IPv4 with the host and port of DEFECTDOJO_URL "
                  "(a test hook; leave it unset)", file=sys.stderr)
            raise Preflight()

    print("DefectDojo host: {}".format(urllib.parse.urlsplit(url).hostname))

    # Token file: a regular file, private to the owner, readable, holding one bare 40-hex token.
    # FATAL lines name the path, never the content.
    try:
        st = os.stat(token_file)
    except OSError:
        print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} does not exist or cannot be read".format(token_file), file=sys.stderr)
        raise Preflight()
    if not stat.S_ISREG(st.st_mode):
        print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} is not a regular file".format(token_file), file=sys.stderr)
        raise Preflight()
    if (st.st_mode & 0o077) != 0:
        print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} is readable by group or other (mode {:o}); chmod 600 it".format(
            token_file, st.st_mode & 0o777), file=sys.stderr)
        raise Preflight()
    try:
        with open(token_file, encoding="utf-8", errors="replace", newline="") as handle:
            token = handle.read()
    except OSError as exc:
        print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} cannot be read: {}".format(token_file, exc.strerror),
              file=sys.stderr)
        raise Preflight()
    # Strip at most one trailing line ending; anything else must fail the format check.
    if token.endswith("\r\n"):
        token = token[:-2]
    elif token.endswith("\n"):
        token = token[:-1]
    if not TOKEN_RE.fullmatch(token):
        print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} must hold one bare DefectDojo API token: "
              "40 lowercase hex characters on one line, no 'Token ' prefix".format(token_file), file=sys.stderr)
        raise Preflight()

    tls_args = []
    if ca_file:
        if not os.path.isfile(ca_file):
            print("FATAL: DEFECTDOJO_CA_FILE {!r} does not exist".format(ca_file), file=sys.stderr)
            raise Preflight()
        tls_args = ["--cacert", ca_file]

    write_private(hdr_path, "Authorization: Token {}\n".format(token))
    del token

    row = read_settings(tls_args)
    drift = drifted(row)
    if not drift:
        print("NO CHANGE: all 5 settings already match (enable_deduplication, delete_duplicates, "
              "false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days)")
        return 0

    write_private(body_path, json.dumps({k: DESIRED[k] for k in drift}))
    patched = api(tls_args, "PATCH", "/api/v2/system_settings/{}/".format(row["id"]), "200", body=body_path)
    if not isinstance(patched, dict):
        print("FAILED: PATCH /api/v2/system_settings/{}/ http=200 but the response is not an object".format(row["id"]))
        raise Failed()
    print("CHANGED: {}".format(", ".join(drift)))

    still = drifted(read_settings(tls_args))
    if still:
        print("FAILED: after PATCH these settings still do not match: {}".format(", ".join(still)))
        raise Failed()
    print("VERIFIED: all 5 settings match")
    return 0


try:
    try:
        rc = main()
    except Failed:
        rc = 1
    except Preflight:
        rc = 2
finally:
    for leftover in (hdr_path, body_path, resp_path):
        if os.path.exists(leftover):
            os.remove(leftover)
    os.rmdir(tmpdir)
sys.exit(rc)
PY
