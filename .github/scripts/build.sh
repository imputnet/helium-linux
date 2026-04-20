#!/bin/bash
set -euxo pipefail

. "/repo/scripts/shared.sh"

setup_environment

if [ "$_runner_environment" = "github-hosted" ]; then
    export SCCACHE_GHA_ENABLED=on
    export SCCACHE_GHA_VERSION="$_build_arch"
else  # depot
    export SCCACHE_WEBDAV_KEY_PREFIX="$_build_arch"
fi

if [ "$_prepare_only" = true ]; then
    fetch_sources true true
    apply_patches
    apply_domsub
    helium_substitution
    helium_apply_translations
    helium_version
    helium_resources
    write_gn_args
    fix_tool_downloading
    setup_toolchain
    gn_gen
else
    _task_timeout=18000
    cd "$_src_dir"

    set +e
    timeout -k 5m -s INT "${_task_timeout}"s ninja -C out/Default chrome chromedriver
    rc=$?
    set -e

    if [ "${_gha_final}" != "true" ] && [ "$rc" -eq 124 ]; then
        echo "Task timed out after ${_task_timeout}s; continuing in next run."
        echo "status=running" >> "$GITHUB_OUTPUT"
        exit 0
    elif [ "$rc" -eq 0 ] && [ -x "${_out_dir}/helium" ] && [ -x "${_out_dir}/chromedriver" ]; then
        echo "status=completed" >> "$GITHUB_OUTPUT"
    fi

    exit "$rc"
fi
