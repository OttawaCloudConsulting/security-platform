#!/bin/bash
# containers group on macOS: Homebrew Docker CLI and plugins, Colima as the
# engine. The installer never starts the Colima VM.
# shellcheck source=../../common/handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

brew_tool docker-cli docker docker 'docker --version'
brew_tool docker-engine colima colima 'colima version'
brew_tool docker-compose docker-compose docker-compose 'docker-compose version'
brew_tool docker-buildx docker-buildx docker-buildx 'docker-buildx version'
