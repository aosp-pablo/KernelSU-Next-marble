#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

run_case() {
  local name="$1"
  local log_content="$2"
  local expected_code="$3"
  local expected_name="$4"
  local expected_tag="$5"
  local expected_sig_size="$6"
  local expected_sig_hash="$7"
  local expected_supported="$8"

  local case_dir="${tmp_dir}/${name}"
  local release_dir="${case_dir}/release"
  local refs_file="${case_dir}/resolved-refs.env"
  mkdir -p "${release_dir}"
  printf '%s\n' "${log_content}" > "${release_dir}/build.log"
  : > "${refs_file}"

  if ! KERNEL_DIR="${case_dir}" RESOLVED_REFS_FILE="${refs_file}" \
    bash scripts/read-manager-build-metadata.sh >/dev/null; then
    echo "FAIL: ${name} exited non-zero" >&2
    exit 1
  fi

  local actual_code actual_name actual_tag actual_sig_size actual_sig_hash actual_supported
  actual_code="$(sed -n 's/^manager_build_version_code=//p' "${refs_file}")"
  actual_name="$(sed -n 's/^manager_build_version_name=//p' "${refs_file}")"
  actual_tag="$(sed -n 's/^manager_build_tag=//p' "${refs_file}")"
  actual_sig_size="$(sed -n 's/^manager_signature_size=//p' "${refs_file}")"
  actual_sig_hash="$(sed -n 's/^manager_signature_hash=//p' "${refs_file}")"
  actual_supported="$(sed -n 's/^manager_supported_line=//p' "${refs_file}")"

  [[ "${actual_code}" == "${expected_code}" ]] || {
    echo "FAIL: ${name}: code expected '${expected_code}', got '${actual_code}'" >&2
    exit 1
  }
  [[ "${actual_name}" == "${expected_name}" ]] || {
    echo "FAIL: ${name}: name expected '${expected_name}', got '${actual_name}'" >&2
    exit 1
  }
  [[ "${actual_tag}" == "${expected_tag}" ]] || {
    echo "FAIL: ${name}: tag expected '${expected_tag}', got '${actual_tag}'" >&2
    exit 1
  }
  [[ "${actual_sig_size}" == "${expected_sig_size}" ]] || {
    echo "FAIL: ${name}: signature size expected '${expected_sig_size}', got '${actual_sig_size}'" >&2
    exit 1
  }
  [[ "${actual_sig_hash}" == "${expected_sig_hash}" ]] || {
    echo "FAIL: ${name}: signature hash expected '${expected_sig_hash}', got '${actual_sig_hash}'" >&2
    exit 1
  }
  [[ "${actual_supported}" == "${expected_supported}" ]] || {
    echo "FAIL: ${name}: supported line expected '${expected_supported}', got '${actual_supported}'" >&2
    exit 1
  }

  if ! source "${refs_file}"; then
    echo "FAIL: ${name}: resolved refs file is not source-safe" >&2
    exit 1
  fi
}

run_case kernelsu \
  $'-- KernelSU version: 32523\n-- KernelSU Manager signature size: 0x033b\n-- KernelSU Manager signature hash: c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6' \
  '32523' '' '' '0x033b' 'c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6' ''

run_case kernelsu_next \
  $'-- KernelSU-Next version: 33201\n-- KernelSU-Next tag: v3.2.0\n-- KernelSU-Next Manager signature size: 0x3e6\n-- KernelSU-Next Manager signature hash: 79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7' \
  '33201' '' 'v3.2.0' '0x3e6' '79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7' ''

run_case sukisu_ultra \
  $'-- SukiSU-Ultra version: 40813 [v4.1.3-b88403d2@HEAD]\n-- SukiSU-Ultra: using SUSFS_INLINE_HOOK' \
  '40813' 'v4.1.3-b88403d2@HEAD' '' '' '' ''

run_case resukisu \
  $'-- ReSukiSU version code: 34989\n-- ReSukiSU version name: v4.1.0-d0f59d06@ReSukiSU\n-- Supported Unofficial Manager: MKSU, RKSU, KOWSU, SukiSU-Ultra, ReSukiSU' \
  '34989' 'v4.1.0-d0f59d06@ReSukiSU' '' '' '' 'MKSU,RKSU,KOWSU,SukiSU-Ultra,ReSukiSU'

run_case no_metadata \
  $'CC drivers/example.o' \
  '' '' '' '' '' ''

echo "Manager build metadata tests passed"
