# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Old provider pin: satisfies D-02 and seeds Phase 16 / SCA-03.
# NOTE: the provider pin alone produces ZERO Checkov findings. The misconfigured
# resources below are what make the IaC job non-empty (see RESEARCH C-2).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
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
