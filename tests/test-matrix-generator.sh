#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

matrix="$(
  BUILD_KERNELSU_NEXT=true \
  BUILD_SUKISU_ULTRA=true \
  BUILD_RESUKISU=true \
  GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh
)"

python3 - "${matrix}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
items = data["include"]
assert [item["manager"] for item in items] == [
    "kernelsu-next",
    "sukisu-ultra",
    "resukisu",
]
assert [item["enable_susfs"] for item in items] == ["true", "true", "true"]
assert [item["label"] for item in items] == [
    "kernelsu-next-susfs",
    "sukisu-ultra-susfs",
    "resukisu-susfs",
]
PY

# KernelSU alone should have susfs disabled
matrix_ksu="$(
  BUILD_KERNELSU=true \
  GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh
)"
python3 - "${matrix_ksu}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
items = data["include"]
assert [item["manager"] for item in items] == ["kernelsu"]
assert [item["enable_susfs"] for item in items] == ["false"]
assert [item["label"] for item in items] == ["kernelsu"]
PY

echo "Matrix generator tests passed"

# ENABLE_SUSFS=false override forces all managers to disable SUSFS
matrix_optout="$(
  ENABLE_SUSFS=false \
  BUILD_KERNELSU_NEXT=true \
  BUILD_SUKISU_ULTRA=true \
  BUILD_RESUKISU=true \
  GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh
)"
python3 - "${matrix_optout}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
items = data["include"]
assert [item["manager"] for item in items] == [
    "kernelsu-next",
    "sukisu-ultra",
    "resukisu",
]
assert [item["enable_susfs"] for item in items] == ["false", "false", "false"]
assert [item["label"] for item in items] == [
    "kernelsu-next",
    "sukisu-ultra",
    "resukisu",
]
print("SUSFS opt-out override test passed")
PY
