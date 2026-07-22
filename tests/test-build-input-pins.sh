#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

source config/marble.env

[[ "${ANYKERNEL3_REF:-}" =~ ^[0-9a-f]{40}$ ]] || {
  echo "FAIL: ANYKERNEL3_REF must be a full commit SHA" >&2
  exit 1
}

[[ "${ANDROID_CLANG_REF_COMMIT:-}" =~ ^[0-9a-f]{40}$ ]] || {
  echo "FAIL: ANDROID_CLANG_REF_COMMIT must be a full commit SHA" >&2
  exit 1
}

[[ "${LLVM_22_1_8_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || {
  echo "FAIL: LLVM_22_1_8_SHA256 must be a full SHA-256 digest" >&2
  exit 1
}

[[ "${LLVM_22_1_8_URL:-}" == https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-Linux-X64.tar.xz ]] || {
  echo "FAIL: LLVM 22.1.8 URL must point at the official Linux X64 release asset" >&2
  exit 1
}

grep -q 'fetch --depth=1 origin "${ANYKERNEL3_REF}"' scripts/package-anykernel.sh || {
  echo "FAIL: AnyKernel3 fetch is not pinned to ANYKERNEL3_REF" >&2
  exit 1
}

grep -q 'anykernel3_commit=' scripts/package-anykernel.sh || {
  echo "FAIL: AnyKernel3 commit is not recorded in metadata" >&2
  exit 1
}

echo "Build input pin tests passed"
