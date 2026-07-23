#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

workflow=.github/workflows/build-matrix.yml
preflight=.github/workflows/preflight.yml

[[ -f "${workflow}" ]] || {
  echo "FAIL: build workflow is missing" >&2
  exit 1
}

required_patterns=(
  'workflow_dispatch:'
  'contents: read'
  'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
  'actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
  'actions/attest@281a49d4cbb0a72c9575a50d18f6deb515a11deb'
  'persist-credentials: false'
  'git clone --filter=blob:none --no-checkout --depth=1'
  'ANDROID_CLANG_REF_COMMIT'
  'LLVM_22_1_8_SHA256'
  'compression-level: 0'
  'retention-days: 30'
  'marble-builder-ccache-v4-'
  'Restore ThinLTO cache'
  'Save ThinLTO cache'
  'marble-builder-thinlto-v1-'
  'runner_image_version='
  'ccache_hit='
  'Read manager build metadata'
  'Write build-info JSON'
  'Generate artifact attestation'
)

for pattern in "${required_patterns[@]}"; do
  grep -Fq "${pattern}" "${workflow}" || {
    echo "FAIL: workflow missing pattern: ${pattern}" >&2
    exit 1
  }
done

if grep -Eq 'debug_artifacts|marble-debug-|Upload debug artifacts|retention-days: 7' "${workflow}"; then
  echo "FAIL: debug artifact upload path must stay removed" >&2
  exit 1
fi

grep -Fq '!cancelled()' "${workflow}" || {
  echo "FAIL: ccache/ThinLTO save must allow failed builds via !cancelled()" >&2
  exit 1
}
grep -Fq 'always()' "${workflow}" || {
  echo "FAIL: object-cache save steps should use always() so they run after a failed build" >&2
  exit 1
}

grep -Fq 'CCACHE_COMPILERCHECK=content' scripts/build-kernel.sh || {
  echo "FAIL: ccache compiler validation is not content-based" >&2
  exit 1
}
grep -Fq 'ccache -M 4G' scripts/build-kernel.sh || {
  echo "FAIL: ccache maximum is not 4 GiB" >&2
  exit 1
}
grep -Fq 'compression=true' scripts/build-kernel.sh || {
  echo "FAIL: ccache compression must stay enabled" >&2
  exit 1
}
grep -Fq 'compression_level=6' scripts/build-kernel.sh || {
  echo "FAIL: ccache compression_level=6 should be configured when supported" >&2
  exit 1
}

if grep -Fq 'CCACHE_COMPILERCHECK=none' scripts/build-kernel.sh; then
  echo "FAIL: unsafe ccache compiler checking remains enabled" >&2
  exit 1
fi

[[ -f scripts/lib/summary-common.sh ]] || {
  echo "FAIL: shared summary helper library is missing" >&2
  exit 1
}

grep -Fq 'source scripts/lib/summary-common.sh' scripts/generate-build-summary.sh || {
  echo "FAIL: single summary does not use shared summary helpers" >&2
  exit 1
}

grep -Fq 'source scripts/lib/summary-common.sh' scripts/generate-matrix-summary.sh || {
  echo "FAIL: matrix summary does not use shared summary helpers" >&2
  exit 1
}

[[ ! -e .github/workflows/build-marble.yml ]] || {
  echo "FAIL: obsolete single-build workflow must be removed" >&2
  exit 1
}
[[ ! -e .github/workflows/release-core.yml ]] || {
  echo "FAIL: obsolete same-run release workflow must be removed" >&2
  exit 1
}
[[ ! -e .github/workflows/build-core.yml ]] || {
  echo "FAIL: obsolete reusable workflow must be removed" >&2
  exit 1
}

grep -Fq 'concurrency:' "${workflow}" || {
  echo "FAIL: workflow does not guard duplicate runs with concurrency" >&2
  exit 1
}

grep -Fq 'kernel_source:' "${workflow}" || {
  echo "FAIL: workflow does not expose the kernel_source dropdown" >&2
  exit 1
}

grep -Fq -- "- aosp-pablo" "${workflow}" || {
    echo "FAIL: workflow missing kernel_source option: aosp-pablo" >&2
    exit 1
}
grep -Fq -- "- aospa-pablo" "${workflow}" || {
    echo "FAIL: workflow missing kernel_source option: aospa-pablo" >&2
    exit 1
}

grep -Fq 'scripts/resolve-kernel-source.sh' "${workflow}" || {
  echo "FAIL: workflow does not resolve kernel source presets" >&2
  exit 1
}

[[ -f config/kernel-sources.json ]] || {
  echo "FAIL: config/kernel-sources.json is missing" >&2
  exit 1
}

grep -Fq 'toolchain:' "${workflow}" || {
  echo "FAIL: workflow does not expose the toolchain selector" >&2
  exit 1
}

grep -Fq 'default: auto' "${workflow}" || {
  echo "FAIL: workflow must default toolchain to auto" >&2
  exit 1
}

grep -Fq 'llvm-22.1.8' "${workflow}" || {
  echo "FAIL: workflow does not expose LLVM 22.1.8 as an option" >&2
  exit 1
}

grep -Fq 'Resolve toolchain' "${workflow}" || {
  echo "FAIL: workflow must resolve toolchain=auto after kernel preset" >&2
  exit 1
}

grep -Fq 'resolve-toolchain.sh' "${workflow}" || {
  echo "FAIL: workflow must call scripts/resolve-toolchain.sh" >&2
  exit 1
}

grep -Fq 'lto:' "${workflow}" || {
  echo "FAIL: workflow does not expose the lto input" >&2
  exit 1
}

grep -Fq 'default: thin' "${workflow}" || {
  echo "FAIL: workflow must default lto to thin" >&2
  exit 1
}

for lto_opt in none thin full; do
  grep -Fq -- "- ${lto_opt}" "${workflow}" || {
    echo "FAIL: workflow missing lto option: ${lto_opt}" >&2
    exit 1
  }
done

if ! grep -Eq 'Setup swap|swap-size-gb' "${workflow}"; then
  echo "FAIL: workflow must set up swap for LTO builds" >&2
  exit 1
fi

required_toolchain_patterns=(
  'Restore LLVM 22.1.8'
  'Fetch LLVM 22.1.8'
  'sha256sum -c -'
  'LLVM_22_1_8_URL'
  'LLVM_22_1_8_SHA256'
  'ACTIVE_TOOLCHAIN_VERSION'
  'ACTIVE_TOOLCHAIN_ID'
  'ACTIVE_TOOLCHAIN_DIGEST'
)
for pattern in "${required_toolchain_patterns[@]}"; do
  grep -Fq -- "${pattern}" "${workflow}" || {
    echo "FAIL: workflow missing toolchain pattern: ${pattern}" >&2
    exit 1
  }
done

grep -Fq 'create_draft_release:' "${workflow}" || {
  echo "FAIL: workflow does not expose the draft release input" >&2
  exit 1
}

grep -Fq 'create_draft_release: true' "${workflow}" && {
  echo "FAIL: draft release input must default to false" >&2
  exit 1
}

required_release_patterns=(
  'inputs.create_draft_release == true'
  "needs.build.result == 'success'"
  "needs.aggregate-summary.result == 'success'"
  'contents: write'
  'bash scripts/prepare-promoted-release.sh'
  'mapfile -t release_assets < release-assets.txt'
  'gh release create "${tag}" "${release_assets[@]}"'
  '--draft'
)
for pattern in "${required_release_patterns[@]}"; do
  grep -Fq -- "${pattern}" "${workflow}" || {
    echo "FAIL: release job missing pattern: ${pattern}" >&2
    exit 1
  }
done

if grep -Eq 'make_release|environment: release-approval|build_run_id' "${workflow}"; then
  echo "FAIL: workflow must not use old promotion inputs or environment deployments" >&2
  exit 1
fi

grep -Fq 'bash scripts/generate-build-matrix.sh' "${workflow}" || {
  echo "FAIL: workflow is not using the data-driven matrix generator" >&2
  exit 1
}

required_setup_tests=(
  'tests/test-workflow-policy.sh'
  'tests/test-lto-policy.sh'
  'tests/test-manager-policy.sh'
  'tests/test-matrix-generator.sh'
  'tests/test-susfs-presets.sh'
)
for test in "${required_setup_tests[@]}"; do
  grep -Fq "${test}" "${workflow}" || {
    echo "FAIL: workflow setup missing fast policy test: ${test}" >&2
    exit 1
  }
done

if grep -Fq 'for test_script in tests/test-*.sh' "${workflow}"; then
  echo "FAIL: setup should run a fast subset, not all tests/test-*.sh" >&2
  exit 1
fi

grep -Fq 'marble-matrix-summary-r${{ github.run_number }}' "${workflow}" || {
  echo "FAIL: workflow must upload combined summary artifact" >&2
  exit 1
}

grep -Fq 'Generate combined summary' "${workflow}" || {
  echo "FAIL: workflow does not generate a combined summary" >&2
  exit 1
}

grep -Fq 'pattern: marble-flash-*-r${{ github.run_number }}' "${workflow}" || {
  echo "FAIL: workflow does not download all matrix flash artifacts by pattern" >&2
  exit 1
}

[[ -f .github/dependabot.yml ]] || {
  echo "FAIL: Dependabot configuration is missing" >&2
  exit 1
}
grep -Fq 'package-ecosystem: github-actions' .github/dependabot.yml || {
  echo "FAIL: Dependabot does not track GitHub Actions" >&2
  exit 1
}

[[ -f "${preflight}" ]] || {
  echo "FAIL: preflight workflow is missing" >&2
  exit 1
}

for pattern in 'bash tests/test-*.sh' 'bash -n scripts/*.sh scripts/lib/*.sh tests/*.sh' 'actionlint' 'shellcheck -e SC1090,SC1091,SC2016,SC2153,SC2154'; do
  grep -Fq "${pattern}" "${preflight}" || {
    echo "FAIL: preflight workflow missing pattern: ${pattern}" >&2
    exit 1
  }
done

[[ ! -e .github/workflows/promote-release.yml ]] || {
  echo "FAIL: separate promote workflow must be removed" >&2
  exit 1
}

echo "Workflow policy tests passed"
