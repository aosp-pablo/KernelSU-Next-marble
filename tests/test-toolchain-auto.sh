#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

out="$(KERNEL_SOURCE=aosp-pablo SOURCE_REF='' TOOLCHAIN=auto bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=llvm-22.1.8' || {
  echo "FAIL: aosp-pablo auto should resolve to llvm-22.1.8 (got: ${out})" >&2
  exit 1
}

out="$(KERNEL_SOURCE=aosp-pablo SOURCE_REF='' TOOLCHAIN=android-r416183b bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=android-r416183b' || {
  echo "FAIL: explicit override should stick (got: ${out})" >&2
  exit 1
}

echo "Toolchain auto tests passed"
