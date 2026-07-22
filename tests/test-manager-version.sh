#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

run_case() {
  local name="$1"
  local makefile_content="$2"
  local expected="$3"
  local case_dir="${tmp_dir}/${name}"
  local refs_file="${case_dir}/resolved-refs.env"

  mkdir -p "${case_dir}/kernel-source/KernelSU/kernel"
  printf '%s\n' "${makefile_content}" > "${case_dir}/kernel-source/KernelSU/kernel/Makefile"
  : > "${refs_file}"

  if ! KERNEL_DIR="${case_dir}/kernel-source" \
    RESOLVED_REFS_FILE="${refs_file}" \
    MANAGER=kernelsu \
    bash scripts/read-manager-version.sh >/dev/null; then
    echo "FAIL: ${name} exited non-zero" >&2
    exit 1
  fi

  actual="$(sed -n 's/^manager_version_code=//p' "${refs_file}" | tail -n1)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: ${name}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

# Literal Makefile values (no git) — previous Marble behavior, still required.
run_case literal-kernelsu 'KERNELSU_VERSION := 12345' '12345'
run_case literal-ksu 'KSU_VERSION = 13000' '13000'
run_case whitespace '  KSU_VERSION  :=  14000  ' '14000'
run_case dynamic 'KSU_VERSION := $(shell expr 1 + 2)' ''
run_case missing '# no version assignment' ''

# Wild-style: fake git repo with N commits → code = N + BASE (kernelsu BASE=30000).
wild_dir="${tmp_dir}/wild-ksu"
mkdir -p "${wild_dir}/kernel-source/KernelSU/kernel"
refs_wild="${wild_dir}/resolved-refs.env"
: > "${refs_wild}"
printf '%s\n' 'DKSU_VERSION=16' > "${wild_dir}/kernel-source/KernelSU/kernel/Makefile"
git -C "${wild_dir}/kernel-source/KernelSU" init -q
git -C "${wild_dir}/kernel-source/KernelSU" config user.email "test@example.com"
git -C "${wild_dir}/kernel-source/KernelSU" config user.name "Test"
# Create 3 commits
for i in 1 2 3; do
  echo "c${i}" > "${wild_dir}/kernel-source/KernelSU/f${i}"
  git -C "${wild_dir}/kernel-source/KernelSU" add "f${i}"
  git -C "${wild_dir}/kernel-source/KernelSU" commit -q -m "c${i}"
done

KERNEL_DIR="${wild_dir}/kernel-source" \
  RESOLVED_REFS_FILE="${refs_wild}" \
  MANAGER=kernelsu \
  bash scripts/read-manager-version.sh >/dev/null

wild_code="$(sed -n 's/^manager_version_code=//p' "${refs_wild}" | tail -n1)"
# 3 commits + BASE 30000 = 30003
if [[ "${wild_code}" != "30003" ]]; then
  echo "FAIL: wild-style kernelsu expected 30003, got '${wild_code}'" >&2
  exit 1
fi
if ! grep -qE 'DKSU_VERSION[[:space:]]*=[[:space:]]*30003' \
  "${wild_dir}/kernel-source/KernelSU/kernel/Makefile"; then
  echo "FAIL: DKSU_VERSION was not injected into Makefile" >&2
  cat "${wild_dir}/kernel-source/KernelSU/kernel/Makefile" >&2
  exit 1
fi
if ! grep -q 'manager_version_method=wild-revlist' "${refs_wild}"; then
  echo "FAIL: expected manager_version_method=wild-revlist" >&2
  exit 1
fi
if ! grep -q 'manager_build_version_code=30003' "${refs_wild}"; then
  echo "FAIL: expected manager_build_version_code seeded early" >&2
  exit 1
fi

# KSUN-style base switch: commits < 2684 → base 10200
ksun_dir="${tmp_dir}/wild-ksun"
mkdir -p "${ksun_dir}/kernel-source/KernelSU-Next/kernel"
refs_ksun="${ksun_dir}/resolved-refs.env"
: > "${refs_ksun}"
printf '%s\n' 'DKSU_VERSION=11998' > "${ksun_dir}/kernel-source/KernelSU-Next/kernel/Makefile"
git -C "${ksun_dir}/kernel-source/KernelSU-Next" init -q
git -C "${ksun_dir}/kernel-source/KernelSU-Next" config user.email "test@example.com"
git -C "${ksun_dir}/kernel-source/KernelSU-Next" config user.name "Test"
echo x > "${ksun_dir}/kernel-source/KernelSU-Next/x"
git -C "${ksun_dir}/kernel-source/KernelSU-Next" add x
git -C "${ksun_dir}/kernel-source/KernelSU-Next" commit -q -m "one"

KERNEL_DIR="${ksun_dir}/kernel-source" \
  RESOLVED_REFS_FILE="${refs_ksun}" \
  MANAGER=kernelsu-next \
  bash scripts/read-manager-version.sh >/dev/null

ksun_code="$(sed -n 's/^manager_version_code=//p' "${refs_ksun}" | tail -n1)"
# 1 commit + BASE 10200 = 10201
if [[ "${ksun_code}" != "10201" ]]; then
  echo "FAIL: wild-style ksunext expected 10201, got '${ksun_code}'" >&2
  exit 1
fi
grep -qE 'DKSU_VERSION[[:space:]]*=[[:space:]]*10201' \
  "${ksun_dir}/kernel-source/KernelSU-Next/kernel/Makefile" || {
  echo "FAIL: KSUN DKSU_VERSION inject failed" >&2
  exit 1
}

echo "Manager version tests passed"
