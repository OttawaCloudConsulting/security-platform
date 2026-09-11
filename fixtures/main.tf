# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Old provider pin: satisfies D-02 only. An exact `3.74.0` pin is correctly SILENT
# under tflint — a pinning check WANTS an exact pin. What seeds SCA-03 is the
# unconstrained `random` provider and the unpinned module block below.
# NOTE: the provider pin alone produces ZERO Checkov findings. The misconfigured
# resources below are what make the IaC job non-empty (see RESEARCH C-2).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
    # No `version` key on purpose — an unconstrained provider is what trips tflint's
    # terraform_required_providers rule, and it only fires when the provider is
    # actually USED by a resource (see random_id.fixture below). Do NOT "fix" this.
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "aws_s3_bucket" "fixture" {
  bucket = "scan-fixture-insecure-bucket"
}

resource "aws_security_group" "fixture" {
  name = "scan-fixture-open"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Registry module with NO `version` argument on purpose — seeds tflint's
# terraform_module_version rule. Nothing ever runs `terraform init` on fixtures/.
module "fixture_unpinned_module" { # 17-05: line deliberately touched — see below
  # DELIBERATE 17-05 EDIT: touched on purpose so the verification PR diff exercises
  # inline annotations (CKV_TF_1, CKV_TF_2 and tflint terraform_module_version).
  source = "terraform-aws-modules/s3-bucket/aws"
}

# Uses the unconstrained `random` provider declared above; without this resource
# terraform_required_providers does not fire at all.
resource "random_id" "fixture" {
  byte_length = 8
}
