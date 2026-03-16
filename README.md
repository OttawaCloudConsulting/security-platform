# security-platform

Canonical security configuration for OttawaCloudConsulting repositories.

## Contents

- `.pre-commit-config.yaml` — Pre-commit hook configuration (Tier 1 quality + Tier 2 secrets)

## Usage

Copy `.pre-commit-config.yaml` to target repository root, then:

    cd <target-repo>
    pre-commit install
    pre-commit run --all-files
