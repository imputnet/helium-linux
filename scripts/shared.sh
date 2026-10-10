# shared build functions used by local and CI scripts

if [ -n "${BASH_VERSION:-}" ]; then
    __helium_shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    __helium_shared_dir="${0:a:h}"
else
    echo "shared.sh only supports bash and zsh" >&2
    return 1 2>/dev/null || exit 1
fi

# resolve repo root directory regardless of caller location
repo_root() {
    cd "${__helium_shared_dir}/.." >/dev/null 2>&1 && pwd
}

setup_arch() {
    _host_arch=$(uname -m)

    if [ "$_host_arch" = "x86_64" ]; then
        _host_arch="x64"
    elif [ "$_host_arch" = "aarch64" ]; then
        _host_arch="arm64"
    fi

    _build_arch="$_host_arch"
    if [ -n "${ARCH:-}" ]; then
        _build_arch="$ARCH"
    fi

    if [ "$_build_arch" = "x86_64" ]; then
        _build_arch=x64
    fi
}

setup_paths() {
    _root_dir="$(repo_root)"
    _main_repo="${_root_dir}/helium-chromium"
    _build_dir="${_root_dir}/build"
    _dl_cache="${_build_dir}/download_cache"
    _src_dir="${_build_dir}/src"
    _out_dir="${_src_dir}/out/Default"

    _subs_cache="${_build_dir}/subs.tar.gz"
    _namesubs_cache="${_build_dir}/namesubs.tar"

    mkdir -p "${_dl_cache}"
}

setup_environment() {
    setup_paths
    setup_arch

    _has_pgo=false
}

fetch_sources() {
    local use_clone="${1:-false}"
    local with_pgo="${2:-false}"
    local stamp="${_src_dir}/.downloaded.stamp"
    _has_pgo=false
    if [ "$with_pgo" = true ] && [ "$_build_arch" = x64 ]; then
        _has_pgo=true
    fi

    if [ -f "${stamp}" ]; then
        echo "Sources already present, skipping download/unpack"
        return 0
    fi

    if [ "$use_clone" = true ]; then
        "${_main_repo}/utils/clone.py" -o "${_src_dir}"
    else
        "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/downloads.ini" "${_root_dir}/downloads.ini" -c "${_dl_cache}"
        "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/downloads.ini" "${_root_dir}/downloads.ini" -c "${_dl_cache}" "${_src_dir}"
    fi

    "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/deps.ini" -c "${_dl_cache}"
    "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/deps.ini" -c "${_dl_cache}" "${_src_dir}"

    touch "${stamp}"
}

apply_patches() {
    if [ ! -f "${_src_dir}/.patched.stamp" ]; then
        "${_main_repo}/utils/prune_binaries.py" --keep-contingent-paths "${_src_dir}" "${_main_repo}/pruning.list"
        "${_main_repo}/utils/patches.py" apply "${_src_dir}" "${_main_repo}/patches" "${_root_dir}/patches"
        touch "${_src_dir}/.patched.stamp"
    fi
}

apply_domsub() {
    if [ ! -f "${_src_dir}/.domsub.stamp" ]; then
        "${_main_repo}/utils/domain_substitution.py" apply -r "${_main_repo}/domain_regex.list" -f "${_main_repo}/domain_substitution.list" "${_src_dir}"
        touch "${_src_dir}/.domsub.stamp"
    fi
}

helium_substitution() {
    python3 "$_main_repo/utils/name_substitution.py" --sub \
        -t "$_src_dir" --backup-path "$_namesubs_cache"
}

helium_apply_translations() {
    python3 "$_main_repo/utils/i18n_apply.py" -t "$_src_dir"
}

helium_version() {
    python3 "$_main_repo/utils/helium_version.py" \
        --tree "$_main_repo" \
        --platform-tree "$_root_dir" \
        --chromium-tree "$_src_dir"
}

helium_resources() {
    python3 "$_main_repo/utils/generate_resources.py" "$_main_repo/resources/generate_resources.txt" "$_main_repo/resources"
    python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"
}

write_gn_args() {
    mkdir -p "${_out_dir}"

    cat "${_main_repo}/flags.gn" "${_root_dir}/flags.linux.gn" | tee "${_out_dir}/args.gn"
    echo "target_cpu = \"$_build_arch\"" | tee -a "${_out_dir}/args.gn"
    echo "v8_target_cpu = \"$_build_arch\"" | tee -a "${_out_dir}/args.gn"

    if [ "$_has_pgo" = true ]; then
        echo "chrome_pgo_phase = 2" | tee -a "${_out_dir}/args.gn"
    fi

    if [ -n "${SISO_REAPI_ADDRESS:-}" ]; then
        echo 'use_remoteexec = true' | tee -a "${_out_dir}/args.gn"
    elif command -v sccache >/dev/null 2>&1 && env | grep -q ^SCCACHE; then
        echo 'cc_wrapper = "sccache"' | tee -a "${_out_dir}/args.gn"
    elif command -v ccache >/dev/null; then
        echo 'cc_wrapper = "ccache"' | tee -a "${_out_dir}/args.gn"
    fi
}

configure_remoteexec() {
    if [ -z "${SISO_REAPI_ADDRESS:-}" ]; then
        return 0
    fi

    export SISO_REAPI_INSTANCE="${SISO_REAPI_INSTANCE:-main}"
    export RBE_service_no_security=true

    python3 "${_src_dir}/build/config/siso/configure_siso.py" \
        --reapi_address="${SISO_REAPI_ADDRESS}" \
        --reapi_instance="${SISO_REAPI_INSTANCE}" \
        --reapi_backend_config_path=nativelink.star
}

gn_gen() {
    cd "${_src_dir}"
    ./buildtools/linux64/gn gen out/Default --fail-on-unused-args
}

build() {
    cd "${_src_dir}"
    configure_remoteexec
    local siso="${SISO_PATH:-${_src_dir}/third_party/siso/cipd/siso}"
    local autoninja="${_src_dir}/third_party/depot_tools/autoninja.py"
    SISO_PATH="$siso" "$autoninja" -C "$_out_dir" chrome chromedriver "$@"
}
