#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SSH_KEY="${JACKAL_AUTONOMY_SSH_KEY:-${HOME}/.ssh/id_ed25519_ankit}"
UPDATE_MODE="pinned"

if [ "${1:-}" = "--remote" ]; then
  UPDATE_MODE="remote"
elif [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--remote]"
  exit 2
fi

if [ ! -f "$SSH_KEY" ]; then
  echo "ERROR: SSH key not found: $SSH_KEY"
  echo "Set JACKAL_AUTONOMY_SSH_KEY to override the key path."
  exit 1
fi

key_mode="$(stat -c '%a' "$SSH_KEY")"
if [ "$key_mode" != "600" ]; then
  echo "ERROR: Private SSH key must have mode 600: $SSH_KEY (found $key_mode)"
  exit 1
fi

printf -v shell_quoted_key '%q' "$SSH_KEY"
export GIT_SSH_COMMAND="ssh -i $shell_quoted_key -o IdentitiesOnly=yes -o BatchMode=yes"

git -C "$PROJECT_DIR" submodule sync --recursive
if [ "$UPDATE_MODE" = "remote" ]; then
  git -C "$PROJECT_DIR" submodule update --init --remote
  git -C "$PROJECT_DIR" submodule foreach 'git submodule sync --recursive && git submodule update --init --recursive'
else
  git -C "$PROJECT_DIR" submodule update --init --recursive
fi

git -C "$PROJECT_DIR" submodule status --recursive
