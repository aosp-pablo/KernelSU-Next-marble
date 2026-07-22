#!/usr/bin/env bash
set -euo pipefail

KERNEL_SOURCE="${KERNEL_SOURCE:-aosp-pablo}"
SOURCE_REF="${SOURCE_REF:-}"

if [[ ! -f config/kernel-sources.json ]]; then
  echo "::error::config/kernel-sources.json is missing"
  exit 1
fi

eval "$(
  KERNEL_SOURCE="${KERNEL_SOURCE}" SOURCE_REF="${SOURCE_REF}" python3 - config/kernel-sources.json <<'PY'
import json
import os
import shlex
import sys

config_path = sys.argv[1]
kernel_source = os.environ.get("KERNEL_SOURCE", "aosp-pablo")
source_ref_override = os.environ.get("SOURCE_REF", "")

with open(config_path, encoding="utf-8") as fh:
    presets = json.load(fh)

if kernel_source not in presets:
    allowed = ", ".join(sorted(presets))
    print(f"::error::Unknown kernel_source preset: {kernel_source}", file=sys.stderr)
    print(f"Allowed: {allowed}", file=sys.stderr)
    sys.exit(1)

preset = presets[kernel_source]
org = kernel_source
branch = preset.get("branch") or ""
kernel = preset.get("kernel") or {}
modules = preset.get("modules") or {}
devicetrees = preset.get("devicetrees") or {}

kernel_repo = kernel.get("repo") or ""
defconfig = kernel.get("defconfig") or "gki_defconfig"
toolchain = kernel.get("toolchain") or "llvm-22.1.8"
fragments = kernel.get("config_fragments") or []
config_fragments = " ".join(fragments)

if not branch:
    print(f"::error::kernel_source {kernel_source} has no branch", file=sys.stderr)
    sys.exit(1)

if not kernel_repo:
    print(f"::error::kernel_source {kernel_source} has no kernel.repo", file=sys.stderr)
    sys.exit(1)

source_repo = f"{org}/{kernel_repo}"
resolved_ref = source_ref_override or branch

additional_checkouts = []
if modules and modules.get("repo"):
    additional_checkouts.append({
        "repo": f"{org}/{modules['repo']}",
        "ref": branch,
        "target": "modules",
    })
if devicetrees and devicetrees.get("repo"):
    additional_checkouts.append({
        "repo": f"{org}/{devicetrees['repo']}",
        "ref": branch,
        "target": "sm8450-devicetrees",
    })

values = {
    "KERNEL_SOURCE": kernel_source,
    "SOURCE_REPO": source_repo,
    "SOURCE_REF": resolved_ref,
    "DEFCONFIG_MODE": "gki_fragments",
    "BASE_DEFCONFIG": defconfig,
    "CONFIG_FRAGMENTS": config_fragments,
    "RECOMMENDED_TOOLCHAIN": toolchain,
    "ADDITIONAL_CHECKOUT_COUNT": str(len(additional_checkouts)),
}
for key, value in values.items():
    print(f"{key}={shlex.quote(value)}")
for i, checkout in enumerate(additional_checkouts, 1):
    print(f"ADDITIONAL_CHECKOUT_{i}_REPO={shlex.quote(checkout.get('repo', ''))}")
    print(f"ADDITIONAL_CHECKOUT_{i}_REF={shlex.quote(checkout.get('ref', ''))}")
    print(f"ADDITIONAL_CHECKOUT_{i}_TARGET={shlex.quote(checkout.get('target', ''))}")
PY
)"

mkdir -p release
{
  echo "KERNEL_SOURCE=$(printf '%q' "${KERNEL_SOURCE}")"
  echo "SOURCE_REPO=$(printf '%q' "${SOURCE_REPO}")"
  echo "SOURCE_REF=$(printf '%q' "${SOURCE_REF}")"
  echo "DEFCONFIG_MODE=$(printf '%q' "${DEFCONFIG_MODE}")"
  echo "BASE_DEFCONFIG=$(printf '%q' "${BASE_DEFCONFIG}")"
  echo "CONFIG_FRAGMENTS=$(printf '%q' "${CONFIG_FRAGMENTS}")"
  echo "RECOMMENDED_TOOLCHAIN=$(printf '%q' "${RECOMMENDED_TOOLCHAIN}")"
  echo "ADDITIONAL_CHECKOUT_COUNT=$(printf '%q' "${ADDITIONAL_CHECKOUT_COUNT:-0}")"
  for i in $(seq 1 "${ADDITIONAL_CHECKOUT_COUNT:-0}"); do
    var_repo="ADDITIONAL_CHECKOUT_${i}_REPO"
    var_ref="ADDITIONAL_CHECKOUT_${i}_REF"
    var_target="ADDITIONAL_CHECKOUT_${i}_TARGET"
    echo "${var_repo}=$(printf '%q' "${!var_repo}")"
    echo "${var_ref}=$(printf '%q' "${!var_ref}")"
    echo "${var_target}=$(printf '%q' "${!var_target}")"
  done
} > release/kernel-source.env

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "KERNEL_SOURCE=${KERNEL_SOURCE}"
    echo "SOURCE_REPO=${SOURCE_REPO}"
    echo "SOURCE_REF=${SOURCE_REF}"
    echo "DEFCONFIG_MODE=${DEFCONFIG_MODE}"
    echo "BASE_DEFCONFIG=${BASE_DEFCONFIG}"
    echo "CONFIG_FRAGMENTS=${CONFIG_FRAGMENTS}"
    echo "RECOMMENDED_TOOLCHAIN=${RECOMMENDED_TOOLCHAIN}"
    echo "ADDITIONAL_CHECKOUT_COUNT=${ADDITIONAL_CHECKOUT_COUNT:-0}"
    for i in $(seq 1 "${ADDITIONAL_CHECKOUT_COUNT:-0}"); do
      var_repo="ADDITIONAL_CHECKOUT_${i}_REPO"
      var_ref="ADDITIONAL_CHECKOUT_${i}_REF"
      var_target="ADDITIONAL_CHECKOUT_${i}_TARGET"
      echo "${var_repo}=${!var_repo}"
      echo "${var_ref}=${!var_ref}"
      echo "${var_target}=${!var_target}"
    done
  } >> "${GITHUB_ENV}"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "source_repo=${SOURCE_REPO}"
    echo "source_ref=${SOURCE_REF}"
    echo "kernel_source=${KERNEL_SOURCE}"
  } >> "${GITHUB_OUTPUT}"
fi

echo "Resolved kernel source '${KERNEL_SOURCE}'"
echo "  repo=${SOURCE_REPO}"
echo "  ref=${SOURCE_REF}"
echo "  defconfig=${BASE_DEFCONFIG}"
echo "  fragments=${CONFIG_FRAGMENTS}"
echo "  toolchain=${RECOMMENDED_TOOLCHAIN}"
if [[ -n "${TOOLCHAIN:-}" && "${TOOLCHAIN}" != "${RECOMMENDED_TOOLCHAIN}" ]]; then
  echo "::warning::kernel_source '${KERNEL_SOURCE}' recommends toolchain '${RECOMMENDED_TOOLCHAIN}' (selected: ${TOOLCHAIN}). Older Android clang may fail on armv9 flags."
fi
