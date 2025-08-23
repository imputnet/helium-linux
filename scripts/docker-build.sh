#!/bin/bash
set -euo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && cd .. && pwd)"
_image="chromium-builder:trixie-slim"

if [ -z "${_use_existing_image:-}" ]; then
    echo "building docker image '${_image}'"
    cd "${_base_dir}/docker" && docker buildx build --load -t "${_image}" -f ./build.Dockerfile .
else
    echo "using existing docker image '${_image}'"
fi

# choose entrypoint: CI or local
_entrypoint="/repo/scripts/build.sh"
if [ -n "${CI:-}" ]; then
    _entrypoint="/repo/.github/scripts/build.sh"
fi

# forward relevant envs when set
_extra_env=()
[ -n "${_prepare_only:-}" ] && _extra_env+=(-e "_prepare_only")
[ -n "${_gha_final:-}" ] && _extra_env+=(-e _gha_final)
[ -n "${GITHUB_OUTPUT:-}" ] && _extra_env+=(-e GITHUB_OUTPUT)
[ -n "${ARCH:-}" ] && _extra_env+=(-e ARCH)

for sccache_env_name in $(env | grep ^SCCACHE_ | cut -d= -f1); do
    _extra_env+=(-e "$sccache_env_name")
done

for actions_env_name in $(env | grep ^ACTIONS_ | cut -d= -f1); do
    _extra_env+=(-e "$actions_env_name")
done

# match host user to avoid permission issues on bind mount
_user_uidgid="$(id -u):$(id -g)"

_build_start=$(date)
echo "docker build start at ${_build_start}"

_gha_mount=""

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    _gha_mount="-v $GITHUB_OUTPUT:$GITHUB_OUTPUT"
fi

cd "${_base_dir}" && docker run --rm -i \
    -u "${_user_uidgid}" \
    -v "${_base_dir}:/repo" \
    $_gha_mount \
    -e HOME=/home/builder \
    -e XDG_CONFIG_HOME=/home/builder/.config \
    "${_extra_env[@]}" "${_image}" bash "${_entrypoint}" "$@"

_build_end=$(date)
echo -e "docker build start at ${_build_start}, end at ${_build_end}"
