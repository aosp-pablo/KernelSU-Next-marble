#!/usr/bin/env bash
set -euo pipefail

MATRIX_ARTIFACTS_DIR="${MATRIX_ARTIFACTS_DIR:-matrix-artifacts}"
MATRIX_SUMMARY="${MATRIX_SUMMARY:-matrix-summary.md}"
RELEASE_ASSETS_FILE="${RELEASE_ASSETS_FILE:-release-assets.txt}"
BUILD_SCOPE="${BUILD_SCOPE:-}"
SOURCE_RUN_NUMBER="${SOURCE_RUN_NUMBER:-}"

if [[ ! -d "${MATRIX_ARTIFACTS_DIR}" ]]; then
  echo "::error::Matrix artifacts directory not found: ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

artifact_dirs=()
if [[ -f "${MATRIX_ARTIFACTS_DIR}/build-info.txt" && \
      -f "${MATRIX_ARTIFACTS_DIR}/build-info.json" && \
      -f "${MATRIX_ARTIFACTS_DIR}/zip-name.env" ]]; then
  artifact_dirs+=("${MATRIX_ARTIFACTS_DIR}")
fi

mapfile -d '' -t nested_artifact_dirs < <(
  find "${MATRIX_ARTIFACTS_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z
)
artifact_dirs+=("${nested_artifact_dirs[@]}")
if [[ "${#artifact_dirs[@]}" -eq 0 ]]; then
  echo "::error::No matrix artifacts found in ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

declare -A seen_zip_names=()
assets_tmp="$(mktemp)"
trap 'rm -f "${assets_tmp}"' EXIT
detected_scope=""

for artifact_dir in "${artifact_dirs[@]}"; do
  artifact_name="$(basename "${artifact_dir}")"
  if [[ ! "${artifact_name}" =~ -(image-only|full)-r[0-9]+$ ]]; then
    if [[ "${artifact_dir}" == "${MATRIX_ARTIFACTS_DIR}" && "${BUILD_SCOPE}" =~ ^(image-only|full)$ ]]; then
      artifact_scope="${BUILD_SCOPE}"
    else
      echo "::error::Artifact name does not contain a valid build scope: ${artifact_name}"
      exit 1
    fi
  else
    artifact_scope="${BASH_REMATCH[1]}"
  fi
  if [[ -n "${detected_scope}" && "${artifact_scope}" != "${detected_scope}" ]]; then
    echo "::error::Target run contains mixed build scopes"
    exit 1
  fi
  detected_scope="${artifact_scope}"

  for required_file in build-info.txt build-info.json zip-name.env; do
    if [[ ! -f "${artifact_dir}/${required_file}" ]]; then
      echo "::error::Missing ${required_file} in ${artifact_dir}"
      exit 1
    fi
  done
  if ! python3 -m json.tool "${artifact_dir}/build-info.json" >/dev/null; then
    echo "::error::Invalid build-info.json in ${artifact_dir}"
    exit 1
  fi

  if [[ "$(grep -c '^zip_name=' "${artifact_dir}/zip-name.env")" -ne 1 ]]; then
    echo "::error::Expected one zip_name entry in ${artifact_dir}/zip-name.env"
    exit 1
  fi
  zip_name="$(sed -n 's/^zip_name=//p' "${artifact_dir}/zip-name.env")"
  if [[ ! "${zip_name}" =~ ^[A-Za-z0-9._-]+\.zip$ ]]; then
    echo "::error::Invalid zip_name metadata in ${artifact_dir}"
    exit 1
  fi
  if [[ -n "${seen_zip_names[${zip_name}]:-}" ]]; then
    echo "::error::Duplicate promoted ZIP name: ${zip_name}"
    exit 1
  fi
  seen_zip_names["${zip_name}"]=1

  zip_path="${artifact_dir}/${zip_name}"
  checksum_path="${zip_path}.sha256"
  if [[ ! -f "${zip_path}" || ! -f "${checksum_path}" ]]; then
    echo "::error::Missing ZIP or checksum for ${zip_name}"
    exit 1
  fi

  mapfile -t artifact_zips < <(find "${artifact_dir}" -maxdepth 1 -type f -name '*.zip' -print)
  if [[ "${#artifact_zips[@]}" -ne 1 ]]; then
    echo "::error::Expected exactly one flashable ZIP in ${artifact_dir}"
    exit 1
  fi

  read -r expected_hash expected_name extra < "${checksum_path}" || true
  # Git Bash / binary-mode sha256sum may prefix the filename with '*'.
  expected_name="${expected_name#\*}"
  if [[ ! "${expected_hash:-}" =~ ^[a-fA-F0-9]{64}$ || \
        "${expected_name:-}" != "${zip_name}" || -n "${extra:-}" ]]; then
    echo "::error::Invalid checksum metadata for ${zip_name}"
    exit 1
  fi
  actual_hash="$(sha256sum "${zip_path}" | awk '{print $1}')"
  if [[ "${actual_hash}" != "${expected_hash,,}" ]]; then
    echo "::error::Checksum mismatch for ${zip_name}"
    exit 1
  fi
  echo "${zip_name}: OK"
  realpath "${zip_path}" >> "${assets_tmp}"
done

if [[ ! -s "${assets_tmp}" ]]; then
  echo "::error::No verified flashable ZIPs were selected"
  exit 1
fi

MATRIX_ARTIFACTS_DIR="${MATRIX_ARTIFACTS_DIR}" \
MATRIX_SUMMARY="${MATRIX_SUMMARY}" \
BUILD_SCOPE="${BUILD_SCOPE:-${detected_scope}}" \
SOURCE_RUN_NUMBER="${SOURCE_RUN_NUMBER}" \
  bash scripts/generate-matrix-summary.sh >/dev/null

# Release notes: full matrix summary minus CI-only Cache section.
# shellcheck disable=SC1091
source scripts/lib/summary-common.sh
if [[ -z "${RELEASE_NOTES_FILE:-}" ]]; then
  if [[ "${MATRIX_SUMMARY}" == */* ]]; then
    RELEASE_NOTES_FILE="$(dirname "${MATRIX_SUMMARY}")/matrix-summary-release.md"
  else
    RELEASE_NOTES_FILE="matrix-summary-release.md"
  fi
fi
summary_strip_cache_section "${MATRIX_SUMMARY}" "${RELEASE_NOTES_FILE}"
if grep -E 'marble-ci-cache|^## .*Cache$' "${RELEASE_NOTES_FILE}" >/dev/null; then
  echo "::error::Cache section leaked into release notes file ${RELEASE_NOTES_FILE}"
  exit 1
fi

mv "${assets_tmp}" "${RELEASE_ASSETS_FILE}"
trap - EXIT
echo "Prepared $(wc -l < "${RELEASE_ASSETS_FILE}") verified release ZIP(s)"
echo "Release notes (no CI cache section): ${RELEASE_NOTES_FILE}"
