#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

source config/marble.env

if [[ ! "${SUSFS_COMMIT}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "FAIL: SUSFS_COMMIT in marble.env is not a valid commit SHA" >&2
  exit 1
fi

echo "Known-good pins tests passed"
