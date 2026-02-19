# shellcheck disable=SC2148

if [[ "$(basename -- "$0")" = *bash ]]; then
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/shared.sh"
else
    . "${0:a:h}/shared.sh"
fi

setup_environment

source "$_main_repo/devutils/set_quilt_vars.sh"
export QUILT_PATCHES="$_root_dir/patches"
export QUILT_SERIES="$QUILT_PATCHES/series.merged"
alias quilt='quilt --quiltrc -'

___helium_exit() {
    # restore PS1
    if [ -n "${__helium_orig_ps1+x}" ]; then
        PS1="$__helium_orig_ps1"
        unset __helium_orig_ps1
    fi

    # unset functions from dev.sh
    unset -f he __helium_menu ___helium_exit \
        ___helium_setup_gn ___helium_info_pull ___helium_setup \
        ___helium_reset ___helium_name_substitution ___helium_substitution \
        ___helium_build ___helium_run ___helium_pull \
        ___helium_patches_op ___helium_quilt_push ___helium_quilt_pop

    # unset functions from shared.sh
    unset -f repo_root setup_arch setup_paths setup_environment \
        fetch_sources apply_patches apply_domsub helium_substitution \
        helium_version helium_resources write_gn_args fix_tool_downloading \
        setup_toolchain gn_gen build

    # unset variables
    unset _scripts_dir _root_dir _main_repo _build_dir _dl_cache \
        _src_dir _out_dir _subs_cache _namesubs_cache \
        _host_arch _build_arch _has_pgo __helium_loaded REPO_ROOT

    # unset quilt variables
    unset QUILT_PATCHES QUILT_SERIES \
        QUILT_PUSH_ARGS QUILT_DIFF_OPTS QUILT_PATCH_OPTS \
        QUILT_DIFF_ARGS QUILT_REFRESH_ARGS QUILT_COLORS \
        QUILT_SERIES_ARGS QUILT_PATCHES_ARGS QUILT_PAGER

    # remove alias
    unalias quilt 2>/dev/null

    echo "helium dev environment deactivated" >&2
}

___helium_setup_gn() {
    SCCACHE_ENABLED=y write_gn_args
    echo 'devtools_skip_typecheck = false' | tee -a "${_out_dir}/args.gn"
    sed -i s/is_official_build/is_component_build/ "${_out_dir}/args.gn"
}

___helium_info_pull() {
    fetch_sources false false

    mkdir -p "$_src_dir/out/Default"
    cd "$_src_dir"
}

___helium_setup() {
    if [ -d "$_src_dir/out" ]; then
        echo "$_src_dir/out already exists" >&2
        return
    fi

    rm -rf "$_src_dir" && mkdir -p "$_dl_cache" "$_src_dir"

    ___helium_info_pull
    python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
    helium_resources
    ___helium_setup_gn
    setup_toolchain

    ___helium_patches_op merge

    helium_version

    cd "$_src_dir"
    quilt push -a --refresh

    gn_gen
}

___helium_reset() {
    ___helium_patches_op unmerge || true
    rm -f "$_subs_cache"
    rm -f "$_namesubs_cache"

    (
        mv "$_src_dir" "${_src_dir}x" && \
        rm -rf "${_src_dir}x"
    ) &
}

___helium_name_substitution() {
    if [ "$1" = "nameunsub" ]; then
        python3 "$_main_repo/utils/name_substitution.py" --unsub \
            -t "$_src_dir" --backup-path "$_namesubs_cache"
    elif [ "$1" = "namesub" ]; then
        if [ -f "$_namesubs_cache" ]; then
            echo "$_namesubs_cache exists, are you sure you want to do this?" >&2
            echo "if yes, then delete the $_namesubs_cache file" >&2
            return
        fi

        python3 "$_main_repo/utils/name_substitution.py" --sub \
            -t "$_src_dir" --backup-path "$_namesubs_cache"
    else
        echo "unknown action: $1" >&2
        return
    fi
}

___helium_substitution() {
    if [ "$1" = "unsub" ]; then
        python3 "$_main_repo/utils/domain_substitution.py" revert \
            -c "$_subs_cache" "$_src_dir"

        ___helium_name_substitution nameunsub
    elif [ "$1" = "sub" ]; then
        if [ -f "$_subs_cache" ]; then
            echo "$_subs_cache exists, are you sure you want to do this?" >&2
            echo "if yes, then delete the $_subs_cache file" >&2
            return
        fi

        ___helium_name_substitution namesub

        python3 "$_main_repo/utils/domain_substitution.py" apply \
            -r "$_main_repo/domain_regex.list" \
            -f "$_main_repo/domain_substitution.list" \
            -c "$_subs_cache" \
            "$_src_dir"
    else
        echo "unknown action: $1" >&2
        return
    fi
}

___helium_build() {
    cd "$_src_dir" && ninja -C out/Default chrome chromedriver
}

___helium_run() {
    cd "$_src_dir" && ./out/Default/helium \
    --user-data-dir="$HOME/.config/net.imput.helium.dev" \
    --enable-ui-devtools=$RANDOM
}

___helium_pull() {
    if [ -f "$_subs_cache" ]; then
        echo "source files are substituted, please run 'he unsub' first" >&2
        return 1
    fi

    cd "$_src_dir" && quilt pop -a || true
    "$_root_dir/devutils/update_patches.sh" unmerge || true

    for dir in "$_root_dir" "$_main_repo"; do
        git -C "$dir" stash \
        && git -C "$dir" fetch \
        && git -C "$dir" rebase origin/main \
        && git -C "$dir" stash pop \
        || true
    done

    "$_root_dir/devutils/update_patches.sh" merge
    cd "$_src_dir" && quilt push -a --refresh
}

___helium_patches_op() {
    python3 "$_main_repo/devutils/update_platform_patches.py" \
        "$1" \
        "$_root_dir/patches"
}

___helium_quilt_push() {
    cd "$_src_dir" && quilt push -a --refresh
}

___helium_quilt_pop() {
    cd "$_src_dir" && quilt pop -a
}

__helium_menu() {
    set -e
    case $1 in
        setup) ___helium_setup;;
        build) ___helium_build;;
        run) ___helium_run;;
        pull) ___helium_pull;;
        sub|unsub) ___helium_substitution "$1";;
        namesub|nameunsub) ___helium_name_substitution "$1";;
        merge) ___helium_patches_op merge;;
        unmerge) ___helium_patches_op unmerge;;
        push) ___helium_quilt_push;;
        pop) ___helium_quilt_pop;;
        resources) helium_resources;;
        reset) ___helium_reset;;
        exit) ___helium_exit;;
        *)
            echo "usage: he (setup | build | run | sub | unsub | namesub | nameunsub | merge | unmerge | push | pop | pull | reset | exit)" >&2
            echo "\tsetup - sets up the dev environment for the first itme" >&2
            echo "\tbuild - prepares a development build binary" >&2
            echo "\trun - runs a development build of helium with dev data dir & ui devtools enabled" >&2
            echo "\tsub - apply google domain and name substitutions" >&2
            echo "\tunsub - undo google domain substitutions" >&2
            echo "\tnamesub - apply only name substitutions" >&2
            echo "\tnameunsub - undo name substitutions" >&2
            echo "\tmerge - merges all patches" >&2
            echo "\tunmerge - unmerges all patches" >&2
            echo "\tpush - applies all patches" >&2
            echo "\tpop - undoes all patches" >&2
            echo "\tresources - copies helium resources (such as icons)" >&2
            echo "\tpull - undoes all patches, pulls, redoes all patches" >&2
            echo "\treset - nukes everything" >&2
            echo "\texit - deactivate the dev environment" >&2
    esac
}

he() {
    if [ "$1" = "exit" ]; then
        ___helium_exit
    else
        (__helium_menu "$@")
    fi
}

if ! (return 0 2>/dev/null); then
    printf "usage:\n\t$ source dev.sh\n\t$ he\n" 2>&1
    exit 1
else
    if [ "${__helium_loaded:-}" = "" ]; then
        __helium_loaded=1
        __helium_orig_ps1="$PS1"
        PS1="🎈 $PS1"
    fi
fi
