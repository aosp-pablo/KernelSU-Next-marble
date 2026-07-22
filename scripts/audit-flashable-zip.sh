#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
zip_env="${release_dir}/zip-name.env"

if [[ ! -f "${zip_env}" ]]; then
  echo "::error::Missing ${zip_env}"
  exit 1
fi

source "${zip_env}"
zip_path="${release_dir}/${zip_name}"

if [[ ! -s "${zip_path}" ]]; then
  echo "::error::Flashable zip missing or empty: ${zip_path}"
  exit 1
fi

required_entries=(
  "Image"
  "anykernel.sh"
  "LICENSE"
  "META-INF/com/google/android/update-binary"
  "META-INF/com/google/android/updater-script"
  "tools/ak3-core.sh"
  "tools/busybox"
  "tools/magiskboot"
)

zip_listing="$(mktemp)"
unzip -Z1 "${zip_path}" > "${zip_listing}"

missing=0
for entry in "${required_entries[@]}"; do
  if ! grep -Fxq "${entry}" "${zip_listing}"; then
    echo "::error::Missing required zip entry: ${entry}"
    missing=1
  fi
done

if grep -Fxq "README.md" "${zip_listing}"; then
  echo "::error::README.md should not be included in flashable zip"
  missing=1
fi

if [[ "${missing}" -ne 0 ]]; then
  echo "::group::Zip entries"
  cat "${zip_listing}"
  echo "::endgroup::"
  exit 1
fi

zip_size="$(stat -c%s "${zip_path}")"
if [[ "${zip_size}" -lt 5000000 ]]; then
  echo "::error::Flashable zip is unexpectedly small: ${zip_size} bytes"
  exit 1
fi

image_file_type=""
image_in_release="${release_dir}/Image"
if [[ -s "${image_in_release}" ]] && command -v file >/dev/null 2>&1; then
  image_file_type="$(file -b "${image_in_release}" || true)"
  if [[ -n "${image_file_type}" ]] && ! echo "${image_file_type}" | grep -Ei 'ARM|aarch64|MSB|LSB|data|Linux|ELF' >/dev/null; then
    echo "::warning::Image file(1) type unexpected: ${image_file_type}"
  fi
fi

{
  echo "zip_path=${zip_path}"
  echo "zip_size=${zip_size}"
  echo "zip_entries=$(wc -l < "${zip_listing}")"
  echo "image_file_type=${image_file_type}"
} > "${release_dir}/zip-audit.txt"

rm -f "${zip_listing}"
echo "Flashable zip audit passed: ${zip_path}"
