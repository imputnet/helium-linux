#!/bin/bash
set -euo pipefail

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
    _root="$(repo_root)"
    _main_repo="${_root}/ungoogled-chromium"
    _build_dir="${_root}/build"
    _dl_cache="${_build_dir}/download_cache"
    _src_dir="${_build_dir}/src"
    _out_dir="${_src_dir}/out/Default"
    setup_arch

    mkdir -p "${_dl_cache}"
}

fetch_sources() {
    local use_clone="${1:-false}"
    local stamp="${_src_dir}/.downloaded.stamp"

    if [ -f "${stamp}" ]; then
        echo "Sources already present, skipping download/unpack"
        return 0
    fi

    if ${use_clone}; then
        _host_arch_clone="$_host_arch"
        if [ "$_host_arch_clone" = x64 ]; then
            _host_arch_clone="amd64"
        fi

        "${_main_repo}/utils/clone.py" --sysroot "$_host_arch_clone" -o "${_src_dir}"
    else
        "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/downloads.ini" -c "${_dl_cache}"
        "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/downloads.ini" -c "${_dl_cache}" "${_src_dir}"
    fi

    touch "${stamp}"
}

apply_patches() {
    if [ ! -f "${_src_dir}/.patched.stamp" ]; then
        "${_main_repo}/utils/prune_binaries.py" "${_src_dir}" "${_main_repo}/pruning.list"
        "${_main_repo}/utils/patches.py" apply "${_src_dir}" "${_main_repo}/patches" "${_root}/patches"
        touch "${_src_dir}/.patched.stamp"
    fi
}

apply_domsub() {
    if [ ! -f "${_src_dir}/.domsub.stamp" ]; then
        "${_main_repo}/utils/domain_substitution.py" apply -r "${_main_repo}/domain_regex.list" -f "${_main_repo}/domain_substitution.list" "${_src_dir}"
        touch "${_src_dir}/.domsub.stamp"
    fi
}

write_gn_args() {
    mkdir -p "${_out_dir}"

    cat "${_main_repo}/flags.gn" "${_root}/flags.linux.gn" | tee "${_out_dir}/args.gn"
    echo "target_cpu = \"$_build_arch\"" | tee -a "${_out_dir}/args.gn"
    echo "v8_target_cpu = \"$_build_arch\"" | tee -a "${_out_dir}/args.gn"
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
    mkdir -p "${_src_dir}/third_party/gperf/cipd/bin/"
    ln -sf "$(which gperf)" "${_src_dir}/third_party/gperf/cipd/bin/gperf"

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

maybe_build() {
    cd "${_src_dir}"
    ninja -C out/Default chrome chromedriver
}
