#!/bin/bash
# aws group on macOS: shared AWS tools plus SAM from Homebrew.
# shellcheck source=../../common/aws-shared.sh
. "$WST_ROOT/scripts/common/aws-shared.sh"

brew_tool aws-sam aws-sam-cli sam 'sam --version'
