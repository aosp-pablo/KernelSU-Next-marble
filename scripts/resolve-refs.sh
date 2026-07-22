#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

MANAGER="${MANAGER:-kernelsu-next}"
MANAGER_REF="${MANAGER_REF:-}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"

mkdir -p release

source_commit="$(git -C "${KERNEL_DIR}" rev-parse HEAD)"
manager_repo=""
manager_effective_ref=""
manager_commit=""
manager_tag=""
manager_setup_path=""
susfs_commit=""
susfs_reported_version=""
susfs_url=""

manager_repo="$(jq -r --arg manager "${MANAGER}" '.[$manager].repo' config/managers.json)"
manager_default_ref="$(jq -r --arg manager "${MANAGER}" '.[$manager].ref' config/managers.json)"

if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  susfs_repo_override="$(jq -r --arg manager "${MANAGER}" '.[$manager].susfs.repo // empty' config/managers.json)"
  if [[ -n "${susfs_repo_override}" ]]; then
    manager_repo="${susfs_repo_override}"
  fi
  susfs_ref_override="$(jq -r --arg manager "${MANAGER}" '.[$manager].susfs.ref // empty' config/managers.json)"
  if [[ -n "${susfs_ref_override}" ]]; then
    manager_default_ref="${susfs_ref_override}"
  fi
fi

manager_effective_ref="${MANAGER_REF:-${manager_default_ref}}"
manager_setup_path="$(jq -r --arg manager "${MANAGER}" '.[$manager].setup_path' config/managers.json)"

if command -v gh >/dev/null 2>&1; then
  manager_commit="$(gh api "repos/${manager_repo}/commits/${manager_effective_ref}" --jq .sha)"
else
  manager_commit="$(git ls-remote "https://github.com/${manager_repo}.git" \
    "refs/heads/${manager_effective_ref}" "refs/tags/${manager_effective_ref}^{}" "refs/tags/${manager_effective_ref}" |
    awk 'NR == 1 { print $1 }')"
  if [[ -z "${manager_commit}" && "${manager_effective_ref}" =~ ^[0-9a-fA-F]{40}$ ]]; then
    manager_commit="${manager_effective_ref}"
  fi
fi
if [[ -z "${manager_commit}" ]]; then
  echo "::error::Could not resolve manager ref ${manager_repo}@${manager_effective_ref}"
  exit 1
fi

all_tags="$(git ls-remote --tags "https://github.com/${manager_repo}.git" 2>/dev/null || true)"
manager_tag="$(echo "${all_tags}" | awk -v sha="${manager_commit}" \
  '$1==sha && /\^\{\}$/ { sub(/.*refs\/tags\//, "", $2); sub(/\^\{\}/, "", $2); print; exit }')"
if [[ -z "${manager_tag}" ]]; then
  manager_tag="$(echo "${all_tags}" | awk -v sha="${manager_commit}" \
    '$1==sha { sub(/.*refs\/tags\//, "", $2); print; exit }')"
fi

if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  susfs_commit="${SUSFS_COMMIT}"

  tmp_susfs="$(mktemp -d)"
  cleanup_tmp_susfs() {
    local dir="${1:-}"
    [[ -n "${dir}" && -d "${dir}" ]] || return 0
    chmod -R u+w "${dir}" 2>/dev/null || true
    rm -rf "${dir}" 2>/dev/null || true
  }
  trap 'cleanup_tmp_susfs "${tmp_susfs}"' EXIT

  git clone --filter=blob:none --no-checkout "${SUSFS_REPO}" "${tmp_susfs}"
  git -C "${tmp_susfs}" checkout "${susfs_commit}"
  susfs_reported_version="$(
    find "${tmp_susfs}/kernel_patches" -path '*/include/linux/susfs.h' -type f -print0 2>/dev/null |
      xargs -0 -r grep -hoE 'SUSFS_VERSION[[:space:]]+"v[0-9]+\.[0-9]+\.[0-9]+"' 2>/dev/null |
      head -n1 |
      sed -E 's/.*"(v[^"]+)".*/\1/' || true
  )"

  cleanup_tmp_susfs "${tmp_susfs}"
  trap - EXIT

  susfs_url="https://gitlab.com/simonpunk/susfs4ksu/-/commit/${susfs_commit}"
fi

{
  echo "source_commit=${source_commit}"
  echo "manager=${MANAGER}"
  echo "manager_repo=${manager_repo}"
  echo "manager_ref=${manager_effective_ref}"
  echo "manager_commit=${manager_commit}"
  echo "manager_tag=${manager_tag}"
  echo "manager_setup_path=${manager_setup_path}"
  echo "enable_susfs=${ENABLE_SUSFS}"
  echo "susfs_kernel_branch=${SUSFS_KERNEL_BRANCH}"
  echo "susfs_commit=${susfs_commit}"
  echo "susfs_reported_version=${susfs_reported_version}"
  echo "susfs_url=${susfs_url}"
} | tee release/resolved-refs.env
