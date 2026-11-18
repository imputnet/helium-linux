# shellcheck disable=SC2148

if [ -n "${BASH_VERSION:-}" ]; then
    _dev_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _dev_dir="${0:a:h}"
else
    echo "dev.sh only supports bash and zsh" >&2
    return 1 2>/dev/null || exit 1
fi

. "${_dev_dir}/shared.sh"
unset _dev_dir

setup_environment

source "$_main_repo/devutils/set_quilt_vars.sh"
export QUILT_PATCHES="$_root_dir/patches"
export QUILT_SERIES="$QUILT_PATCHES/series.merged"
alias quilt='quilt --quiltrc -'

___helium_setup_gn() {
    SCCACHE_ENABLED=y write_gn_args
    sed -i s/is_official_build/is_component_build/ "${_out_dir}/args.gn"
}

___helium_info_pull() {
    fetch_sources "${1:-false}" false

    mkdir -p "$_src_dir/out/Default"
    cd "$_src_dir"
}

___helium_setup() {
    local clone=false
    if [ $# -eq 1 ] && [ "$1" = -c ]; then
        clone=true
    elif [ $# -ne 0 ]; then
        echo "usage: he setup [-c]" >&2
        return 1
    fi

    if [ -d "$_src_dir/out" ]; then
        echo "$_src_dir/out already exists" >&2
        return
    fi

    rm -rf "$_src_dir" && mkdir -p "$_dl_cache" "$_src_dir"

    ___helium_info_pull "$clone"
    python3 "$_main_repo/utils/prune_binaries.py" --keep-build-dependencies "$_src_dir" "$_main_repo/pruning.list"
    helium_resources
    ___helium_setup_gn

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
    build -k 0
}

___helium_run() {
    local profile="$HOME/.config/net.imput.helium.dev"
    # .git is a file in linked worktrees, and a directory in the main checkout
    if [ -f "$_root_dir/.git" ]; then
        profile="$profile.wt/${_root_dir#*.wt/}"
    fi

    cd "$_src_dir" && ./out/Default/helium \
    --user-data-dir="$profile" \
    --enable-ui-devtools=$RANDOM "$@"
}

___helium_wt_path() {
    local common
    common=$(git -C "$_root_dir" rev-parse --path-format=absolute --git-common-dir)
    echo "$(dirname "$common").wt/$1"
}

___helium_wt_can_reflink() {
    local probe="$1/.reflink-probe.$$"
    cp --reflink=always "$_src_dir/buildtools/linux64/gn" "$probe" 2>/dev/null || return 1
    rm -f "$probe"
}

___helium_wt_new() {
    local copy=false name dest
    if [ "${1:-}" = --copy ]; then
        copy=true
        shift
    fi

    name=${1:?usage: he wt new [--copy] <name>}
    dest=$(___helium_wt_path "$name")
    if [ ! -f "$_root_dir/patches/series.merged" ] || [ ! -d "$_src_dir/.pc" ]; then
        echo "$_src_dir must be set up with merged patches applied" >&2
        return 1
    fi

    if git -C "$_root_dir" rev-parse -q --verify "refs/heads/$name" >/dev/null \
        || git -C "$_main_repo" rev-parse -q --verify "refs/heads/$name" >/dev/null; then
        echo "branch $name already exists" >&2
        return 1
    fi

    mkdir -p "$(dirname "$dest")"
    if [ "$copy" = false ] && ! ___helium_wt_can_reflink "$(dirname "$dest")"; then
        echo "$(dirname "$dest") doesn't support reflinks, so $_src_dir would be copied in full" >&2
        echo "use 'he wt new --copy $name' to do that anyway" >&2
        return 1
    fi

    git -C "$_root_dir" worktree add -b "$name" "$dest" HEAD
    git -C "$_main_repo" worktree add -b "$name" "$dest/helium-chromium" HEAD

    git -C "$_root_dir" diff --binary HEAD -- . ":!patches" ":!helium-chromium" \
        | git -C "$dest" apply --allow-empty
    git -C "$_main_repo" diff --binary HEAD -- . ":!patches" \
        | git -C "$dest/helium-chromium" apply --allow-empty

    rm -rf "$dest/patches"
    cp -a --reflink=auto "$_root_dir/patches" "$dest/patches"

    mkdir -p "$dest/build"
    ln -s "$_dl_cache" "$dest/build/download_cache"
    cp -a --reflink=auto "$_src_dir" "$dest/build/src"
    for f in "$_subs_cache" "$_namesubs_cache"; do
        [ ! -f "$f" ] || cp -a --reflink=auto "$f" "$dest/build/"
    done

    printf '%s\n' "$dest/patches" > "$dest/build/src/.pc/.quilt_patches"
    (cd "$dest" && . scripts/dev.sh && gn_gen)
}

___helium_wt_rm() {
    local dest
    dest=$(___helium_wt_path "${1:?usage: he wt rm <name>}")
    [ -f "$dest/.git" ] || { echo "$dest is not a worktree" >&2; return 1; }
    rm -rf "$dest/build"
    git -C "$_main_repo" worktree remove --force "$dest/helium-chromium" || true
    git -C "$_root_dir" worktree remove --force "$dest"
}

___helium_wt() {
    case "${1:-}" in
        new) shift; ___helium_wt_new "$@";;
        rm) shift; ___helium_wt_rm "$@";;
        ls) git -C "$_root_dir" worktree list;;
        *)
            echo "usage: he wt <new [--copy] <name>|rm <name>|ls>" >&2
            return 1
    esac
}

___helium_pull() {
    if [ -f "$_subs_cache" ]; then
        echo "source files are substituted, please run 'he unsub' first" >&2
        return 1
    fi

    cd "$_src_dir" && quilt pop -a || true
    ___helium_patches_op unmerge || true

    for dir in "$_root_dir" "$_main_repo"; do
        git -C "$dir" stash \
        && git -C "$dir" fetch \
        && git -C "$dir" rebase origin/main \
        && git -C "$dir" stash pop \
        || true
    done

    ___helium_patches_op merge
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
        setup) shift; ___helium_setup "$@";;
        build) ___helium_build;;
        run) shift; ___helium_run "$@";;
        pull) ___helium_pull;;
        sub|unsub) ___helium_substitution "$1";;
        namesub|nameunsub) ___helium_name_substitution "$1";;
        merge) ___helium_patches_op merge;;
        unmerge) ___helium_patches_op unmerge;;
        push) ___helium_quilt_push;;
        pop) ___helium_quilt_pop;;
        resources) helium_resources;;
        reset) ___helium_reset;;
        translate) helium_apply_translations;;
        wt) shift; ___helium_wt "$@";;
        *)
            printf 'usage: he (setup | build | run | sub | unsub | namesub | nameunsub | merge | unmerge | push | pop | pull | reset | translate | wt)\n' >&2
            printf '\tsetup [-c] - sets up the dev environment, optionally cloning chromium\n' >&2
            printf '\tbuild - prepares a development build binary\n' >&2
            printf '\trun [args] - runs a development build of helium with dev data dir & ui devtools enabled\n' >&2
            printf '\tsub - apply google domain and name substitutions\n' >&2
            printf '\tunsub - undo google domain substitutions\n' >&2
            printf '\tnamesub - apply only name substitutions\n' >&2
            printf '\tnameunsub - undo name substitutions\n' >&2
            printf '\tmerge - merges all patches\n' >&2
            printf '\tunmerge - unmerges all patches\n' >&2
            printf '\tpush - applies all patches\n' >&2
            printf '\tpop - undoes all patches\n' >&2
            printf '\tresources - copies helium resources (such as icons)\n' >&2
            printf '\tpull - undoes all patches, pulls, redoes all patches\n' >&2
            printf '\treset - nukes everything\n' >&2
            printf '\ttranslate - apply translations from i18n folder\n' >&2
            printf '\twt new [--copy] <name> - creates a worktree with a reflink copy of the current source tree,\n' >&2
            printf '\t\tor a full copy with --copy if the filesystem lacks reflinks\n' >&2
            printf '\twt rm <name> - removes a worktree and its source tree, keeping its branches\n' >&2
            printf '\twt ls - lists worktrees\n' >&2
    esac
}

he() {
    (__helium_menu "$@")
}

if ! (return 0 2>/dev/null); then
    printf "usage:\n\t$ source dev.sh\n\t$ he\n" 2>&1
    exit 1
else
    if [ "${__helium_loaded:-}" = "" ]; then
        __helium_loaded=1
        PS1="🎈 $PS1"
    fi
fi
