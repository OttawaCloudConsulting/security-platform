# ADR-029: DefectDojo API Clients Ignore Ambient curl Configuration and Require a Verified TLS Result

**Status:** Accepted
**Date:** 2026-09-30
**Addresses:** Phase 28 CR-01 (28-REVIEW, critical) — an ambient curlrc `insecure` line silently disabled TLS
verification for the superuser-token bootstrap — and the Phase 28 warnings WR-01 (an unreadable or directory token
file crashed with a traceback and exit 1) and WR-02 (token content was not validated, so a multi-line token file
injected request headers)

This record lives in this documentation repository. The public `security-platform` scripts and the reusable workflow
`security.yml` cite it by number (for example the "Runner curl config (ADR-029, Phase 28 CR-01)" paragraph in both
DefectDojo body comment blocks and the CURL CONFIG paragraph in each operator script header), so a reader of the
public repository cannot follow the link. That is the arrangement ADR-022 to ADR-025 recorded. Every measured value
below is quoted from a Phase 29.2 plan summary (29.2-01 to 29.2-08) or from a file in that phase's `evidence/`
directory, and each is attributed where it appears. No homelab address, hostname, token, product name or DefectDojo
instance URL appears here. The only hostnames are the RFC 2606 placeholder `defectdojo.example.com`, the RFC 6761
test name `defectdojo.curlrc.test`, and the loopback address `127.0.0.1` on which the offline proof listener runs.
"Phase 28 CR-01" is this record's trigger; "the Phase 27 CR-01" is the different finding ADR-025 addresses.

## Context

- **An ambient curlrc switched TLS verification off.** `defectdojo-configure.sh` called plain curl, so a curlrc under
  `CURL_HOME` (or `~/.curlrc`, or `$XDG_CONFIG_HOME/curlrc`) was honoured. With a curlrc holding `insecure` and
  `verbose`, the script completed a handshake with a self-signed peer such as `https://defectdojo.example.com` served
  by an attacker, sent `Authorization: Token <superuser token>`, and `verbose` printed that header to stderr
  (28-REVIEW Phase 28 CR-01). Its own header claimed "TLS is always verified" next to "a curlrc under CURL_HOME is
  honoured".
- **ADR-025's "TLS is verified" was not true in code.** ADR-025 refused non-https URLs and kept verification on by
  default, but it never considered curl configuration the process did not set. The same defect was present in every
  DefectDojo API client, not only the bootstrap. 29.2-01 reproduced it offline before any fix: against a self-signed
  python3 listener on `127.0.0.1` with a hostile curlrc, configure, lifecycle-assert, homelab-validate, and the
  committed `dd-import` and `dd-delete` bodies all sent their token (`REQUEST ... auth=yes`), and the harness ended
  `PROOF FAIL - 6 of 14` (`evidence/29.2-01-red.txt`).
- **Measured curl facts shaped the decision.** The phase research measured, with curl 8.7.1 (LibreSSL 3.3.6) against
  a self-signed listener and a hostile curlrc (29.2-RESEARCH, cases A-L):
  - `-q` only works as curl's **first** argument. `-q` first: exit 60, `HANDSHAKE-FAIL`, no request (B). `-sS -q`:
    the curlrc is read and the token is sent (C).
  - `-q` also blocks `$HOME/.curlrc` and `$XDG_CONFIG_HOME/curlrc` (F), and the curlrc's `trace-ascii` and `libcurl`
    output files are never created (D/E).
  - `%{ssl_verify_result}` is `0` on a refused connection (exit 7, no TLS at all) (G), and `0` when a curlrc `cacert`
    line swaps in the attacker's trust root (K). So a verify check alone proves nothing.
  - `-k` against a self-signed peer gives `18` (H). This is the released `DEFECTDOJO_INSECURE=true` path in
    `security.yml`.
  - `CURL_CA_BUNDLE` is honoured even with `-q` (L): it is an environment variable, not curl configuration.
- **A fourth client.** `scripts/defectdojo-homelab-validate.sh` runs against a real instance, sends the admin
  password and an API token with plain curl, and echoed curl stderr on failure. The operator folded it in as a fourth
  target (29.2-CONTEXT D-17).
- **ADR-025 may not be edited.** `docs/adr/` is append-only per `CLAUDE.md`. ADR-025 gives the offline gate as 19
  checks. The precedent for extending an accepted record is a new record that does so in prose (ADR-025 over
  ADR-024 decision 13).

## Decision

This record extends ADR-025 **in prose**: ADR-025's "TLS is verified" now also means ambient curl configuration
cannot switch verification off, and the gate count ADR-025 gives as 19 is now 20. ADR-025 is untouched. Put
plainly, this record extends ADR-025; it supersedes nothing in it.

1. **Every DefectDojo API client passes curl `-q` as argv[1].** The clients are `scripts/defectdojo-configure.sh`,
   `scripts/defectdojo-lifecycle-assert.sh`, `scripts/defectdojo-homelab-validate.sh` (all six curl call sites), and
   the `security.yml` bodies `dd-import` and `dd-delete`. The python call sites build
   `["curl", "-q", "-sS", "--proto", "=https", "--proto-redir", "=https", ...]`; the bash call sites start
   `curl -q -sS --proto =https`. `-q` applies in every TLS mode, including `DEFECTDOJO_INSECURE=true`.
2. **Success requires curl exit 0 AND `ssl_verify_result` 0 AND the expected HTTP code.** Each call writes
   `-w '%{http_code} %{ssl_verify_result} %{errormsg}'` (the bash sites separate the fields with `|`) and checks
   the curl exit first, then the verify result, then the HTTP code. Any other outcome fails with
   `curl exit N, http C, TLS verification result V (must be 0): <errormsg>` and exit 1. The one exception is the
   `security.yml` bodies: when `DEFECTDOJO_INSECURE=true` they skip the verify part
   (`rc != 0 or (tls_mode != "insecure" and verify != "0")`), because the released v1 input maps to `-k`, `-k`
   yields `18`, and an unconditional check would break every insecure-mode consumer on a release that must stay
   additive (29.2-CONTEXT D-16). The operator scripts have no insecure mode and always run the check. The verify
   check is defence in depth; `-q` is what keeps the token off an unverified peer.
3. **`dd-import` stops at the first transport failure.** It prints
   `STOPPED: no further report is sent after a transport or TLS failure`, records the failed report, still writes its
   results file, and exits 1. The unfixed loop kept going (2 CONNECTs and 2 POSTs in 29.2-01).
4. **`DEFECTDOJO_RESOLVE` is a harness-only test hook.** When set, it is passed as one `--resolve <value>`. It must
   fullmatch `host:port:IPv4`, the host must equal the `DEFECTDOJO_URL` host (case-insensitive) and the port must
   equal the URL port (default 443); anything else is refused with exit 2 before any connection, and the value is
   never echoed. Only the IP changes, so hostname verification still applies (for example
   `defectdojo.curlrc.test:443:127.0.0.1` must still present a certificate for `defectdojo.curlrc.test`). The
   workflow never sets it; it is not a `workflow_call` input, repository variable, secret or consumer setting, and
   the adoption guide does not mention it (29.2-CONTEXT D-07). `defectdojo-homelab-validate.sh` has no such hook: it
   reaches real hosts through real DNS, and its header says so.
5. **No raw curl stderr, verbose or trace output in any failure line.** Every call site sends curl stderr to
   `/dev/null` or `subprocess.DEVNULL`, and nothing reads `proc.stderr`. A failure line may carry curl's
   `%{errormsg}` and, on an HTTP-code mismatch after a verified transfer, the DefectDojo response body truncated to
   500 characters, which is the server's JSON, not curl output (29.2-CONTEXT D-08, D-18). A denylist that scrubs
   `Authorization:` lines was rejected as fragile.
6. **Token files are one line of 40 lowercase hex.** `defectdojo-configure.sh`, `defectdojo-lifecycle-assert.sh` and
   `defectdojo-homelab-validate.sh` require the token file to be a regular, readable file whose content, after at
   most one trailing line ending is stripped, fullmatches `[0-9a-f]{40}` with no `Token ` prefix. Anything else is
   refused with exit 2 before any connection, naming the path and never the content (WR-01, WR-02).
7. **The proof.** `scripts/defectdojo-import-proof.sh` gained:
   - **P-CURLRC**, offline and live: a python3 `ssl` listener on `127.0.0.1` with a throwaway self-signed cert, a
     hostile `CURL_HOME` curlrc (`insecure`, `verbose`, `trace-ascii`, `libcurl`, `cacert`, `location`,
     `location-trusted`, `resolve`), a no-`-q` control that proves the curlrc is live, and six target lines
     (configure, lifecycle, homelab-tls-probe, homelab-token-get, dd-import, dd-delete). Each target must exit 1 with
     at least one `HANDSHAKE-FAIL`, 0 requests, the token absent and no trace or libcurl file.
   - **Guard cases** (P-CONFIGURE-GUARD, P-TOKEN-GUARD, P-RESOLVE-GUARD): 16 malformed-token and malformed-hook cases,
     each requiring exit 2 and 0 CONNECT at the listener.
   - **A hostile live curlrc.** In the live `--hook` run the global `CURL_HOME` curlrc carries `insecure`, `verbose`,
     `trace-ascii`, `libcurl`, a throwaway `cacert`, `location` and `location-trusted`, and no `resolve` line. Host
     resolution moved to `DEFECTDOJO_RESOLVE`. A final P-TLS assertion requires that the curlrc's trace and libcurl
     files were never created in the whole run.
   - **The CURLRC gate.** `scripts/check-workflow-uploads.sh` gained a 20th check, CURLRC, so the gate now runs 20
     checks. For each DefectDojo body it requires exactly one `["curl", "-q", "-sS"`, no `["curl", "-sS"`, a read of
     `%{ssl_verify_result}`, `stderr=subprocess.DEVNULL`, no `proc.stderr`, a read of `DEFECTDOJO_RESOLVE`, and no
     `DEFECTDOJO_RESOLVE` key in the step `env` mapping.

### Measured evidence

- **RED (29.2-01, 29.2-02, 29.2-05):** P-CURLRC against the unfixed code: `PROOF FAIL - 6 of 14`, every target sent
  its token (`evidence/29.2-01-red.txt`). With the 16 guard cases added: `PROOF FAIL - 20 of 30`, 14 of the new cases
  failing and 2 passing by design as regression guards (`evidence/29.2-02-red.txt`). The CURLRC gate against the
  unfixed bodies: `FAILED - 12 check(s)`, six conditions for each body and no other check (29.2-05).
- **GREEN, offline (29.2-03 to 29.2-06):** `PROOF FAIL - 13 of 30` after configure (29.2-03), `4 of 30` after the
  operator scripts (29.2-04), then `PROOF PASS - 30 assertions` and `PASS - 20 checks, 0 failures` after the
  `security.yml` bodies (29.2-05, `evidence/29.2-05-green.txt`). After the listener race fix, 25 of 25 consecutive
  `--scheme-only` runs ended `PROOF PASS - 30 assertions` (29.2-06, `evidence/29.2-06-di01-runs.txt`).
- **Listener race (DI-01, 29.2-05 to 29.2-06):** 3 of 33 offline runs after the `security.yml` fix ended
  `PROOF FAIL - 1 of 30` with `no HANDSHAKE-FAIL at the listener`; in each, the body still exited 1 on
  `TLS verification result 18` and the listener saw 0 requests, so the token was never sent. The listener logged
  `HANDSHAKE-FAIL` only once its `wrap_socket` raised, which could happen after the body exited. 29.2-06 made the
  listener log `HANDSHAKE-OK` after a completed handshake and made the harness wait up to 3 s for
  `CONNECT == HANDSHAKE-FAIL + HANDSHAKE-OK` before counting. Injecting a 0.3 s listener delay reproduced the exact
  symptom without the fix and passed with it.
- **Live proof on GitHub (29.2-07):** security-platform PR #27, head `415618cdf390483d48dbbb82d9efc3742ec97251`,
  7 commits. DefectDojo Import Proof run 36742180976 attempt 2 (prove-import job 109981740185) on ubuntu-24.04
  ended `PROOF PASS - 151 assertions` with 0 `PROOF: ... FAIL` lines
  (`evidence/29.2-07-proof-run.log`). 151 = 127 (the live baseline 29.2-06 started from) + 23 (the offline assertions that also run
  in `--hook`) + 1 (the final P-TLS trace-absence line). Attempt 1 of that run failed at `KIND-CELERY-PING` before
  any proof case; the rerun was pre-approved by the operator.
- **The 7th commit (29.2-07):** the first live run (36738325634 attempt 2, head `35363b7`) ended
  `PROOF FAIL - 1 of 151`, only on P-INSECURE. The `--hook`-wide `DEFECTDOJO_RESOLVE` export leaked into that case,
  whose `DD_URL` names a different host, and the `dd-import` hook guard correctly refused it with exit 2. The product
  behaved as designed; the harness case was wrong. `415618c`
  (`fix(29.2-07): P-INSECURE clears DEFECTDOJO_RESOLVE ...`) passes `DEFECTDOJO_RESOLVE=` to that case. On the
  passing run: `P-INSECURE PASS DD_INSECURE=true -> ::warning:: line printed, exit 0`.
- **`HANDSHAKE-OK=2` on the homelab lines is expected.** The live P-CURLRC lines for homelab-tls-probe and
  homelab-token-get read `listener CONNECT=6 HANDSHAKE-FAIL=4 HANDSHAKE-OK=2 REQUEST=0`. The two completed handshakes
  are the script's `openssl s_client | openssl x509 -noout -ext subjectAltName` certificate dump, which does not
  verify and sends no HTTP request (29.2-06 DI-01 investigation). Every curl connection failed the handshake and no
  request arrived. Reviewers should not read the two OKs as a leak.
- **The trace-absence line (29.2-07):** `P-TLS PASS no curl in the live run read the hostile curlrc:
  curlrc-global-trace.txt and curlrc-global-libcurl.c were never created`.
- **Merge (29.2-08):** PR #27 merged with `gh pr merge --merge` as the two-parent merge commit
  `47319b2ed56dfff4353f1fcf22a0b06663bda172` (parents `fdabac9`, the prior main, and `415618c`, the approved head),
  at 2026-09-30T16:46:09Z. Readbacks from `origin/main`: `"curl", "-q", "-sS"` occurs 2 times in `security.yml`,
  `check-workflow-uploads.sh` has `CHECK_COUNT = 20`, and `defectdojo-configure.sh` has `"curl", "-q"` once.
  `scripts/set-required-checks.sh` is byte-identical to `fdabac9`. The `v1*` tag listing is identical to the
  pre-push table: `v1` and `v1.2.0` both still resolve to `fdabac9`, and no tag was created or moved.
- **First live run of a hardened body from `main` (29.2-08):** merging PR #27 fired `PR Security` run 36746622337.
  Its `security / DefectDojo Cleanup` job (109994321686) ran `security.yml@refs/heads/main` at `47319b2` with
  `TLS mode: verified-system`, deleted the PR's engagement (id 4) and concluded success. Nobody acted on DefectDojo
  by hand.
- **The PR's own import ran and passed.** The plan assumed `security / DefectDojo Import` would be skipped on
  security-platform. It is not: security-platform sets `DEFECTDOJO_URL` and imports into a private instance with
  verified TLS. On PR #27 the job passed with `TLS mode: verified-system` and `DefectDojo import verified: 8
  report(s)` (29.2-07). The operator amended the check accordingly.

## Consequences

**Improved:** no DefectDojo API client in `security-platform` can be made to send a token to an unverified peer by a
curlrc, whether the curlrc sits on an operator workstation, a hosted runner or a self-hosted runner (ADR-028). curl
stderr, verbose and trace output can no longer reach a log line, and a malformed token file or hook value stops the
run before any connection.

**Not yet released — `v1` does not carry the `security.yml` part.** The fix merged to `security-platform` `main` at
`47319b2` with no tag. A consumer on `@v1` (or `v1.2.0`, both at `fdabac9`) still runs the unfixed `dd-import` and
`dd-delete` bodies. A consumer on `@main` has the fix now. Phase 29.4, which also changes `security.yml`, cuts one
additive v1.x tag and moves `v1` for 29.2 and 29.4 together (29.2-CONTEXT D-02, ADR-018). The operator scripts are
not part of the `v1` workflow surface; the fixed versions are on `main`.

**Tradeoff — legitimate curlrc entries no longer apply.** A self-hosted runner or operator workstation that relies on
a curlrc for a proxy or a private CA loses it for these calls. Environment variables still apply (`HTTPS_PROXY`,
`NO_PROXY`, `CURL_CA_BUNDLE`), and the supported way to trust a private CA remains `DEFECTDOJO_CA_CERT` for the
workflow and `DEFECTDOJO_CA_FILE` for `defectdojo-configure.sh`.

**Tradeoff — insecure mode stays insecure.** With `DEFECTDOJO_INSECURE=true` the bodies still pass `-q`, so a curlrc
cannot add anything, but they skip the verify check by design (decision 2). The existing `::warning::` line remains the
only signal on that path. Removing the mode would be a breaking change and needs its own phase.

**Tradeoff — hand-set tokens are refused.** A DefectDojo admin key that is not 40 lowercase hex (for example one set
by hand) is refused with exit 2 by the three operator scripts and must be regenerated. DefectDojo's own generator
produces 40-hex keys.

**Changed counts.** The offline gate runs 20 checks (ADR-025 recorded 19). The live proof moved to 151 assertions and
the offline `--scheme-only` proof to 30. ADR-025's counts remain an accurate record of what was measured then.

## What was NOT verified

What WAS measured and must not be re-litigated: the RED runs against the unfixed code (29.2-01, 29.2-02, 29.2-05),
the offline GREEN runs and the 25-run stability check (29.2-05, 29.2-06), the live `PROOF PASS - 151 assertions` on
ubuntu-24.04 (run 36742180976 attempt 2), the merged tree and tag listing on `origin/main` (29.2-08), and the live
cleanup from `main` (run 36746622337).

1. **Environment-scoped weakening is out of scope.** `CURL_CA_BUNDLE` is honoured even with `-q` (measured, case L),
   and `SSL_CERT_FILE`, `SSL_CERT_DIR` (OpenSSL trust store) and `SSLKEYLOGFILE` (session keys written to disk, so the
   traffic including the token can be decrypted) are environment variables, not curl configuration. None of them
   was tested against the fixed code. Whoever controls the process environment already controls the code that runs.
2. **A curlrc `cacert` swap is caught only by `-q`, not by the verify check.** With a curlrc `cacert` naming the
   attacker's certificate, curl reports exit 0 and `ssl_verify_result 0` (measured, case K). The hostile curlrc in
   P-CURLRC and in the live run carries a `cacert` line, but it also carries `insecure`, so no case isolates a
   `cacert`-only curlrc against the fixed code. If `-q` were ever lost, decision 2 would not catch this variant.
3. **The macOS SecureTransport backend was not exercised.** The local measurements used curl 8.7.1 on its LibreSSL
   backend; the live run used ubuntu-24.04's OpenSSL build.
4. **Research assumptions (29.2-RESEARCH A1-A6).** The live run confirmed **A6**: the certificate recipe and the
   python listener work on ubuntu-24.04, giving all 7 P-CURLRC PASS lines (the control plus six targets). It
   confirmed **A2 only in part**: the OpenSSL build reports `TLS verification result 18` for an unverified
   self-signed peer (the live body failure lines). The `-k` gives 18 and refused-connection gives 0 sub-claims were
   measured only on the macOS LibreSSL build; live, P-INSECURE made no request (`attempted=0 skipped=8`). **A1** (the
   ARC runner image's curl version) was not observed. **A3** is item 3 above. **A4** (a truncated response body is
   allowed) was settled by operator decision D-18, not by measurement. **A5** (no hand-set custom admin keys in use)
   remains an assumption.
5. **`scripts/defectdojo-live-smoke.sh` is unhardened tech debt.** It still calls curl without `-q` and echoes curl
   stderr, including on its admin password POST. It targets only the throwaway kind cluster with generated
   credentials, so it was left out of scope (29.2-CONTEXT D-17) and recorded in the project state as tech debt. Its
   curls run in a child process with their own environment, so the final P-TLS trace-absence assertion does not
   cover them (deferred item DI-03, source-verified only).
6. **`DD_TOKEN` content is not validated in the `security.yml` bodies.** A multi-line secret would inject request
   headers, the analogue of WR-02. This was not in scope (29.2-RESEARCH Open Question 4) and is a follow-up.
7. **`defectdojo-homelab-validate.sh` was not run against the real instance in this phase.** Its fix is proven only by
   the offline and kind-hosted P-CURLRC and P-TOKEN-GUARD cases.
8. **P-INSECURE has no offline coverage.** It runs only in the live `--hook` path, which is why the harness leak
   fixed by `415618c` passed every offline gate (deferred item DI-02). The insecure path of both bodies was also run
   by hand against a local self-signed server in 29.2-05 (exit 0 with `DD_INSECURE=true`, exit 1 with verify 18
   otherwise), outside the harness.
9. **No required status checks are enforced on `security-platform` `main`.** A read-only check before the merge found
   no classic branch protection (HTTP 404) and one ruleset (14243983) with only `deletion` and `non_fast_forward`
   rules, so neither the CURLRC gate nor any other context is required, although `scripts/set-required-checks.sh`
   exists (29.2-08, deferred item DI-04). This predates the phase, was not changed by it, and is a follow-up rather
   than a decision of this record.
10. **No real consumer has been observed on the fixed bodies.** The only live runs of the hardened bodies are the
    proof harness and security-platform's own PR import and cleanup.
