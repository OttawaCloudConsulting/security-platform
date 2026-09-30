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

## DI-02 (found in 29.2-07, deferred): P-INSECURE has no offline coverage

P-INSECURE only runs in the live `--hook` path. `--scheme-only` (30 assertions) never reaches it, so the plan-06 regression (the hook-wide `DEFECTDOJO_RESOLVE` export tripped the dd-import host guard, exit 2) passed every offline gate and first surfaced on GitHub (run 36738325634 attempt 2, `PROOF FAIL - 1 of 151`). It was fixed in security-platform 415618c by passing `DEFECTDOJO_RESOLVE=` to the P-INSECURE `run_body` call. The gap is that nothing offline catches a future inherited-environment leak into that case. A candidate fix is to run P-INSECURE, which makes no request, in `--scheme-only` with the hook variable set, so the test proves the case clears it. Owner: a later harness plan, not 29.2.

## DI-03 (found in 29.2-07, deferred): the smoke script's own curls are outside the hostile-curlrc assertion

The final P-TLS assertion shows that no curl run in the proof process tree read the hostile `CURL_HOME` curlrc: `curlrc-global-trace.txt` and `curlrc-global-libcurl.c` were never created. Curls made by the kind smoke script (`KIND-*` checks) run in the parent smoke process, which starts the proof hook as a child, so the hook's hostile `CURL_HOME` export never reaches them. They do NOT pass `-q`: at 47319b2 `scripts/defectdojo-live-smoke.sh` lines 636, 673, 692 and 716 call `curl -sS` without `-q` and echo their stderr files. No live assertion covers them. (Corrected by the orchestrator after plan 09; the earlier wording said they were source-verified as passing `-q`.) Owner: later harness plan.

## DI-04 (found in 29.2-07, RESOLVED in 29.2-08): required status contexts

`GitGuardian Security Checks` shows up on PR #27 as a check context. Branch protection or rulesets on `main` were not read during 29.2-07, so the must-have "required contexts unchanged" was not verified against the protection settings. It rests only on the fact that the `security / ...` contexts ran and passed. Plan 08 should read the required contexts (for example `gh api repos/OttawaCloudConsulting/security-platform/branches/main/protection` or the rulesets API) before it merges.

**Resolution (29.2-08, read-only GETs before the merge).** `gh api .../branches/main/protection` returned HTTP 404 `Branch not protected`. `gh api .../rules/branches/main` returned one ruleset (14243983) with only `deletion` and `non_fast_forward` rules and no `required_status_checks` rule. So `main` has no required status contexts: neither `GitGuardian Security Checks` nor any `security / ...` context is required, and this phase changed nothing about them. `scripts/set-required-checks.sh` on origin/main is byte-identical to fdabac9. The fact that no context is enforced was already true before this phase, and fixing it is out of scope. Evidence: `evidence/29.2-08-post-merge.txt`.

## DI-05 (found in 29.2-07, RESOLVED in 29.2-08): homelab engagement ci/fix/phase-29.2-curlrc

`security / DefectDojo Import` runs against the homelab DefectDojo because the operator amended must-have #3, since `security-platform` does set `DEFECTDOJO_URL`. It has imported into engagement `ci/fix/phase-29.2-curlrc` twice: run 36738325155 (head 35363b7) and run 36742181020 (head 415618c). Each import was 8 reports, `http=201`, `TLS mode: verified-system`. Plan 08 must verify that `security / DefectDojo Cleanup` removes that engagement when the PR is merged or closed, however many tests it holds.

**Resolution (29.2-08, observed only).** Merging PR #27 (merge 47319b2) fired `PR Security` on `pull_request: closed` as run 36746622337, which concluded success. Its job `security / DefectDojo Cleanup` (109994321686) ran `security.yml@refs/heads/main` 47319b2, which is the hardened dd-delete body, under `TLS mode: verified-system`. It logged `DELETED: engagement id=4 name='ci/fix/phase-29.2-curlrc' product=1` and `DefectDojo cleanup verified: outcome=deleted ... deleted_ids=[4]`. No one acted on DefectDojo by hand. Evidence: `evidence/29.2-08-post-merge.txt`.

## Note (29.2-07): plans 05/06 commit-count pins are historical

Plan 05's verify pins exactly 5 commits above origin/main and plan 06's pins exactly 6. The operator approved a 7th commit (415618c, the P-INSECURE fix), so the branch now has 7. Those pins were correct when their plans ran and are now historical. This is a recorded deviation, not a violation. Re-running the plan 05 or 06 verify chain against the current branch will fail on the count alone.
