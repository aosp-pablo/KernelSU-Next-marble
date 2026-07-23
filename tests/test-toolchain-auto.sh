#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

out="$(KERNEL_SOURCE=aosp-pablo SOURCE_REF='' TOOLCHAIN=auto bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=llvm-22.1.8' || {
  echo "FAIL: aosp-pablo should resolve to llvm-22.1.8 (got: ${out})" >&2
  exit 1
}

out="$(KERNEL_SOURCE=aosp-pablo SOURCE_REF='' TOOLCHAIN=android-r416183b bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=llvm-22.1.8' || {
  echo "FAIL: aosp-pablo toolchain is locked to preset (got: ${out})" >&2
  exit 1
}

out="$(KERNEL_SOURCE=aospa-pablo SOURCE_REF='' TOOLCHAIN=auto bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=android-r530567' || {
  echo "FAIL: aospa-pablo should resolve to android-r530567 (got: ${out})" >&2
  exit 1
}

out="$(KERNEL_SOURCE=aospa-pablo SOURCE_REF='' TOOLCHAIN=llvm-22.1.8 bash scripts/resolve-toolchain.sh)"
echo "${out}" | grep -q 'TOOLCHAIN=android-r530567' || {
  echo "FAIL: aospa-pablo toolchain is locked to preset (got: ${out})" >&2
  exit 1
}

echo "Toolchain auto tests passed"
