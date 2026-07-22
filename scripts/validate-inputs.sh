#!/usr/bin/env bash
set -euo pipefail

MANAGER="${MANAGER:-kernelsu-next}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
SOURCE_REPO="${SOURCE_REPO:-}"
SOURCE_REF="${SOURCE_REF:-}"
KERNEL_SOURCE="${KERNEL_SOURCE:-}"
MANAGER_REF="${MANAGER_REF:-}"

case "${MANAGER}" in
  kernelsu|kernelsu-next|sukisu-ultra|resukisu) ;;
  *) echo "::error::Unsupported manager: ${MANAGER}"; exit 1 ;;
esac

if [[ -n "${KERNEL_SOURCE}" ]]; then
  if [[ ! -f config/kernel-sources.json ]]; then
    echo "::error::config/kernel-sources.json is missing"
    exit 1
  fi
  if ! KERNEL_SOURCE="${KERNEL_SOURCE}" python3 - config/kernel-sources.json <<'PY'
import json
import os
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    presets = json.load(fh)
kernel_source = os.environ["KERNEL_SOURCE"]
if kernel_source not in presets:
    print(f"::error::Unsupported kernel_source: {kernel_source}", file=sys.stderr)
    print("Allowed: " + ", ".join(sorted(presets)), file=sys.stderr)
    sys.exit(1)
PY
  then
    exit 1
  fi
fi

case "${ENABLE_SUSFS}" in
  true|false) ;;
  *) echo "::error::ENABLE_SUSFS must be true or false, got ${ENABLE_SUSFS}"; exit 1 ;;
esac

case "${BUILD_SCOPE}" in
  image-only|full) ;;
  *) echo "::error::BUILD_SCOPE must be image-only or full, got ${BUILD_SCOPE}"; exit 1 ;;
esac

LTO="${LTO:-thin}"
case "${LTO}" in
  none|thin|full) ;;
  *) echo "::error::LTO must be none, thin, or full, got ${LTO}"; exit 1 ;;
esac

if [[ "${LTO}" == "full" ]]; then
  echo "::warning::LTO=full is memory-heavy on free GitHub-hosted runners (~7GiB). Prefer thin unless on high-RAM hosts."
fi

if [[ "${MARBLE_DENY_FULL_LTO:-false}" == "true" && "${LTO}" == "full" ]]; then
  echo "::error::LTO=full is denied by MARBLE_DENY_FULL_LTO=true"
  exit 1
fi

if [[ -z "${SOURCE_REPO}" || ! "${SOURCE_REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "::error::SOURCE_REPO must look like owner/repo, got ${SOURCE_REPO}"
  exit 1
fi

if [[ -z "${SOURCE_REF}" || ! "${SOURCE_REF}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "::error::SOURCE_REF contains invalid characters: ${SOURCE_REF}"
  exit 1
fi

if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  case "${MANAGER}" in
    kernelsu)
      echo "::error::Official tiann/KernelSU does not support SUSFS."
      exit 1
      ;;
    kernelsu-next)
      [[ -z "${MANAGER_REF}" || "${MANAGER_REF}" == "dev-susfs" ]] || { echo "::error::KernelSU-Next + SUSFS requires pershoot dev-susfs ref"; exit 1; }
      ;;
    sukisu-ultra)
      [[ -z "${MANAGER_REF}" || "${MANAGER_REF}" == "builtin" ]] || { echo "::error::SukiSU Ultra + SUSFS requires official ref builtin"; exit 1; }
      ;;
    resukisu)
      [[ -z "${MANAGER_REF}" || "${MANAGER_REF}" == "main" ]] || { echo "::error::ReSukiSU + SUSFS requires official ref main"; exit 1; }
      ;;
  esac
fi

echo "Input validation passed"
