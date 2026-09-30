# Phase 29.2 deferred items

## DI-01 (found in 29.2-05, owner 29.2-06): P-CURLRC listener race, "no HANDSHAKE-FAIL at the listener" (RESOLVED in 29.2-06)

**Symptom.** `bash scripts/defectdojo-import-proof.sh --scheme-only` sometimes ends `PROOF FAIL - 1 of 30` with one of:

```
PROOF: P-CURLRC FAIL dd-import: no HANDSHAKE-FAIL at the listener; [listener CONNECT=1 HANDSHAKE-FAIL=0 REQUEST=0]
PROOF: P-CURLRC FAIL dd-delete: no HANDSHAKE-FAIL at the listener; [listener CONNECT=1 HANDSHAKE-FAIL=0 REQUEST=0]
```

**Frequency (observed 2026-09-30, uid 501, after f5a3926).** 3 out of 33 runs failed: the first run of the plan's verify chain, plus loop runs 16 and 26 of 31. dd-import failed once in the loop and dd-delete failed once. The target that failed in the verify-chain run is unknown because its log was discarded. Every other run ended `PROOF PASS - 30 assertions`. Evidence: `evidence/29.2-05-flake-runs.txt`.

**Security property held in every failing run.** The body exited 1 with `FAILED: ...: curl exit 60, http 000, TLS verification result 18 (must be 0)`, and the listener counted REQUEST=0. The token was never sent. Only the harness's evidence of the handshake failure was missing.

**Root cause (from reading the code, not instrumented).** In `write_tls_listener_py`, `Server.get_request` logs `CONNECT` and then calls `ctx.wrap_socket(...)`. It logs `HANDSHAKE-FAIL` only when that call raises, which happens once the listener has processed curl's alert or the connection close. curl, and with it the Python body, can exit before that. `run_body` returns, and `curlrc_counts` reads `CURLRC_LOG` immediately, with no wait for the listener to finish. The same race could in principle hit any single-connection P-CURLRC target. It has only been observed on dd-import and dd-delete.

**Suggested fix (for 29.2-06, which owns `defectdojo-import-proof.sh`).** After `run_body`, before `curlrc_counts` judges the result, poll `CURLRC_LOG` until `CONNECT == HANDSHAKE-FAIL + REQUEST` or a deadline of about 2 s passes, then count. Do not drop the `HANDSHAKE-FAIL >= 1` assertion. 29.2-06's own verify runs `--scheme-only | grep -q '^PROOF PASS - '`, so it will hit this race intermittently unless the fix lands first.

**Why it was not fixed in 29.2-05.** The harness is outside plan 05's `files_modified`. Plan 05's verify requires exactly 5 commits above origin/main, and plan 06's requires exactly 6, so an extra harness commit here would break both.

**Resolution (29.2-06, security-platform commit 35363b7).** The listener now logs `HANDSHAKE-OK` when a handshake completes, so every `CONNECT` ends in exactly one `HANDSHAKE-FAIL` or `HANDSHAKE-OK` line. `curlrc_counts` waits up to 3 s for `CONNECT == HANDSHAKE-FAIL + HANDSHAKE-OK` before it counts, and all four places that judge results call it. On the deadline it counts whatever is logged, adds `not settled after 3s` to the detail, and the existing assertions judge the result. The `HANDSHAKE-FAIL >= 1` assertion is unchanged. The suggested predicate `CONNECT == HANDSHAKE-FAIL + REQUEST` was refined because `openssl s_client` in homelab-validate completes the handshake and sends no request, so that predicate never holds for homelab (2 of its 6 connections). The race was not reproduced naturally in 78 instrumented runs. Injecting a 0.3 s delay into the listener reproduced the exact symptom without the fix, and the run passed with the fix. After the fix, 25 of 25 `--scheme-only` runs ended `PROOF PASS - 30 assertions`. Evidence: `evidence/29.2-06-di01-runs.txt`.
