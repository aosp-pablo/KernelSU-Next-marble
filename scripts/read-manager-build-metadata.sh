#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_log="${release_dir}/build.log"

manager_build_version_code=""
manager_build_version_name=""
manager_build_tag=""
manager_signature_size=""
manager_signature_hash=""
manager_supported_line=""

mkdir -p "$(dirname "${RESOLVED_REFS_FILE}")"

if [[ ! -f "${build_log}" ]]; then
  echo "::warning::Build log not found at ${build_log}; manager build metadata will be empty"
else
  manager_build_version_code="$(
    sed -nE \
      -e 's/.*-- (KernelSU|KernelSU-Next) version:[[:space:]]*([0-9]+).*/\2/p' \
      -e 's/.*-- SukiSU-Ultra version:[[:space:]]*([0-9]+)[[:space:]]+\[[^]]+\].*/\1/p' \
      -e 's/.*-- ReSukiSU version code:[[:space:]]*([0-9]+).*/\1/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"

  manager_build_version_name="$(
    sed -nE \
      -e 's/.*-- SukiSU-Ultra version:[[:space:]]*[0-9]+[[:space:]]+\[([^]]+)\].*/\1/p' \
      -e 's/.*-- ReSukiSU version name:[[:space:]]*(.+)$/\1/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"

  manager_build_tag="$(
    sed -nE 's/.*-- KernelSU-Next tag:[[:space:]]*(.+)$/\1/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"

  manager_signature_size="$(
    sed -nE 's/.*-- (KernelSU|KernelSU-Next) Manager signature size:[[:space:]]*([^[:space:]]+).*/\2/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"

  manager_signature_hash="$(
    sed -nE 's/.*-- (KernelSU|KernelSU-Next) Manager signature hash:[[:space:]]*([0-9a-fA-F]+).*/\2/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"

  manager_supported_line="$(
    sed -nE 's/.*-- Supported Unofficial Manager:[[:space:]]*(.+)$/\1/p' \
      "${build_log}" | head -n1 | tr -d '\r' || true
  )"
  manager_supported_line="${manager_supported_line//, /,}"
fi

{
  echo "manager_build_version_code=${manager_build_version_code}"
  echo "manager_build_version_name=${manager_build_version_name}"
  echo "manager_build_tag=${manager_build_tag}"
  echo "manager_signature_size=${manager_signature_size}"
  echo "manager_signature_hash=${manager_signature_hash}"
  echo "manager_supported_line=${manager_supported_line}"
} >> "${RESOLVED_REFS_FILE}"

if [[ -n "${manager_build_version_code}${manager_build_version_name}${manager_build_tag}" ]]; then
  echo "Manager build metadata: code=${manager_build_version_code:-unknown} name=${manager_build_version_name:-${manager_build_tag:-unknown}}"
else
  echo "::warning::Manager build metadata not found in ${build_log}"
fi
