#!/bin/bash

# shared build functions used by local and CI scripts

# resolve repo root directory regardless of caller location
repo_root() {
    local _base_dir
    _base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
    cd "${_base_dir}/.." >/dev/null 2>&1 && pwd
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

    if [ -f "${stamp}" ]; then
        echo "Sources already present, skipping download/unpack"
        return 0
    fi

    if [ "$with_pgo" = true ] && [ "$use_clone" != true ]; then
        echo "builds with pgo need to use clone, specify -c" >&2
        exit 1
    fi

    if [ "$use_clone" = true ]; then
        local _host_arch_clone="$_host_arch"
        local _pgo_args=()

        if [ "$_host_arch_clone" = x64 ]; then
            _host_arch_clone="amd64"
        fi

        if [ "$with_pgo" = true ]; then
            if [ "$_build_arch" = x64 ]; then
                _pgo_args=(-p linux)
                _has_pgo=true
            else
                echo "pgo profiles are currently supported for x86_64 only" >&2
                echo "build arch is $_build_arch, skipping pgo download" >&2
            fi
        fi

        HOME=$(mktemp -d)
        XDG_CONFIG_HOME="$HOME/.config"
        export HOME XDG_CONFIG_HOME

        "${_main_repo}/utils/clone.py" \
            --sysroot "$_host_arch_clone" \
            "${_pgo_args[@]}" \
            -o "${_src_dir}"
    else
        "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/downloads.ini" -c "${_dl_cache}"
        "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/downloads.ini" -c "${_dl_cache}" "${_src_dir}"

        # TODO: remove this after google starts including dawn_commit_hash.h in tarballs
        patch -p1 -d "$_src_dir" < "$_root_dir/patches/ungoogled-chromium/portablelinux/fix-tarball-dawn-commit-hash.patch"
    fi

    "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/extras.ini" -c "${_dl_cache}"
    "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/extras.ini" -c "${_dl_cache}" "${_src_dir}"

    touch "${stamp}"
}

apply_patches() {
    if [ ! -f "${_src_dir}/.patched.stamp" ]; then
        "${_main_repo}/utils/prune_binaries.py" "${_src_dir}" "${_main_repo}/pruning.list"
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

    if command -v sccache >/dev/null 2>&1 && env | grep -q ^SCCACHE; then
        echo 'cc_wrapper = "sccache"' | tee -a "${_out_dir}/args.gn"
    elif command -v ccache >/dev/null; then
        echo 'cc_wrapper = "ccache"' | tee -a "${_out_dir}/args.gn"
    fi
}

# fix downloading of prebuilt tools and sysroot files
# (https://github.com/ungoogled-software/ungoogled-chromium/issues/1846)
fix_tool_downloading() {
    sed -i 's/commondatastorage.9oo91eapis.qjz9zk/commondatastorage.googleapis.com/g' \
        "${_src_dir}/build/linux/sysroot_scripts/sysroots.json" \
        "${_src_dir}/tools/clang/scripts/update.py" \
        "${_src_dir}/tools/clang/scripts/build.py"

    sed -i 's/chromium.9oo91esource.qjz9zk/chromium.googlesource.com/g' \
        "${_src_dir}/tools/clang/scripts/build.py" \
        "${_src_dir}/tools/rust/build_rust.py" \
        "${_src_dir}/tools/rust/build_bindgen.py"

    sed -i 's/chrome-infra-packages.8pp2p8t.qjz9zk/chrome-infra-packages.appspot.com/g' \
        "${_src_dir}/tools/rust/build_rust.py"
}

setup_toolchain() {
    # Chromium currently has no non-x86 llvm/rust builds on
    # Linux, so we have to build it ourselves.
    if [ "$_host_arch" = x64 ]; then
        "${_src_dir}/tools/rust/update_rust.py"
        "${_src_dir}/tools/clang/scripts/update.py"
    else
        "${_src_dir}/tools/clang/scripts/build.py" \
            --without-fuchsia --without-android --disable-asserts \
            --host-cc=clang --host-cxx=clang++ --use-system-cmake \
            --with-ml-inliner-model=

        export CARGO_HOME="${_src_dir}/third_party/rust-src/cargo-home"
        "${_src_dir}/tools/rust/build_rust.py" \
            --skip-test

        "${_src_dir}/tools/rust/build_bindgen.py"
    fi

    if grep -q -F "use_sysroot=true" "${_out_dir}/args.gn"; then
        "${_src_dir}/build/linux/sysroot_scripts/install-sysroot.py" --arch="$_host_arch" &
        if [ "$_build_arch" != "$_host_arch" ]; then
            "${_src_dir}/build/linux/sysroot_scripts/install-sysroot.py" --arch="$_build_arch" &
        fi
        wait
    fi

    mkdir -p "${_src_dir}/third_party/node/linux/node-linux-x64/bin"
    ln -sf "$(which node)" "${_src_dir}/third_party/node/linux/node-linux-x64/bin/node"

    local clang_bin="${_src_dir}/third_party/llvm-build/Release+Asserts/bin"
    export CC="${clang_bin}/clang"
    export CXX="${clang_bin}/clang++"
    export AR="${clang_bin}/llvm-ar"
    export NM="${clang_bin}/llvm-nm"
    export LLVM_BIN="${clang_bin}"

    local resource_dir
    resource_dir="$(${CC%% *} --print-resource-dir)"
    export CXXFLAGS+=" -resource-dir=${resource_dir} -B${LLVM_BIN}"
    export CPPFLAGS+=" -resource-dir=${resource_dir} -B${LLVM_BIN}"
    export CFLAGS+=" -resource-dir=${resource_dir} -B${LLVM_BIN}"
}

gn_gen() {
    cd "${_src_dir}"
    ./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
    ./out/Default/gn gen out/Default --fail-on-unused-args
}

build() {
    cd "${_src_dir}"
    ninja -C out/Default chrome chromedriver
}
