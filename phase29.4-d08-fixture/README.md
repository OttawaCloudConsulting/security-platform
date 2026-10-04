# Phase 29.4 D-08 fixture

Phase 29.4 D-08 live dedup fixture — never merge.

This directory exists only on the `phase29.4/d08-image-dedup-fixture` branch. It gives the
PR-security run one new Semgrep finding, so the DefectDojo `ci/<branch>` engagement has
exactly one untriaged finding, while the trivy-image findings of the same run are measured
as duplicates of their ci/main counterparts. The pull request is closed unmerged and the
branch deleted.
