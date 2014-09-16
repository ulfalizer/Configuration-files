#!/bin/bash

# This file is meant to be included from the main Bash configuration file

# Reload configuration
alias reload=". ~/conf/bash"

# Misc. aliases

alias -- -="cd - >/dev/null"
# autocd would also take care of '..', but the alias avoids the annoying
# "cd .." printout
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias ll="ls -l"
# Lists most recently modified files last
alias new="ls -lrt"

# Preference variables

export EDITOR=vim

# Default but with system calls before commands
export MANSECT=2:n:l:8:3:1:3posix:3pm:3perl:5:4:9:6:7

# General shell options

if (( ${BASH_VERSINFO[0]} >= 4 )); then
    shopt -s autocd
    shopt -s globstar
fi

# Prints an error together with the name of the calling function. Second
# argument (defaults to 1) is how far to look up the call stack for the name.
_err() { echo "${FUNCNAME[${2-1}]}: $1" >&2 }

# Helper function for printing a usage string. Second argument like for _err().
_usage() { echo "usage: ${FUNCNAME[${2-1}]} $1" >&2 }

# Helper function. Checks if a program exists in the search path.
_prg_exists() { type -P -- "$1" >/dev/null }

# Safe rm command with trash directory.
#
# usage: rm <file> [<file> ...]
#
# Removes directories as well as files. Removed files are stored in $trash_dir,
# which is emptied by running
#
# $ empty_trash
#
# Handles filenames and paths that contain spaces and/or start with '-'
# gracefully. Creates backups when deleting identically-named files so that no
# files are permanently removed until 'empty_trash' is run.

trash_dir=/tmp/trash

alias rm=safe_rm

# Helper function. Checks that trash_dir can be safely used.

_trash_dir_is_ok() {
    if [[ -z $trash_dir ]]; then
        _err "trash_dir is not set" 2
        return 1
    fi

    if [[ $trash_dir != /* ]]; then
        _err "trash_dir (set to '$trash_dir') is not an absolute path" 2
        return 1
    fi

    if [[ -e $trash_dir && ! -d $trash_dir ]]; then
        _err "trash_dir (set to '$trash_dir') is not a directory" 2
        return 1
    fi

    return 0
}

safe_rm() {
    # The usage and error helpers will say "safe_rm" instead of "rm", but
    # that's probably ok since it reminds us that we're dealing with a function

    local error

    # Use the system's rm if we're running from an interactively source'd
    # script or from another function
    if [[ ${#FUNCNAME[@]} -gt 1 ]]; then
        command rm "$@"
        return $?
    fi

    if [[ $# -eq 0 ]]; then
        _usage "<file> [<file> ...]"
        return 1
    fi

    _trash_dir_is_ok || return 1

    for f in "$@"; do
        # -e is false for broken symbolic links; hence the -h test
        if [[ ! -e $f && ! -h $f ]]; then
            _err "'$f' does not exist"
            return 1
        fi
        if [[ ! -w $(dirname -- "$f") ]]; then
            _err "cannot remove '$f': No write permissions for containing directory"
            return 1
        fi
    done

    mkdir -p -- "$trash_dir"
    if [[ ! -e $trash_dir ]]; then
        _err "failed to create trash_dir (set to '$trash_dir')"
        return 1
    fi

    mv -f --backup=numbered -- "$@" "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        _err "failed to move files into trash_dir (set to '$trash_dir')"
        return $error
    fi
}

empty_trash() {
    local error

    if [[ $# -gt 0 ]]; then
        _usage "(no arguments)"
        return 1
    fi

    _trash_dir_is_ok || return 1

    [[ -e $trash_dir ]] || return 0

    if [[ ! -w $(dirname -- "$trash_dir") ]]; then
        _err "cannot remove '$trash_dir': No write permissions for containing directory"
        return 1
    fi

    command rm -rf -- "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        _err "failed to remove '$trash_dir'"
        return $error
    fi
}

# Helper function. For files, cd's to the directory. For ordinary files, cd's
# to the containing directory.

_cd_to() {
    if [[ -d $1 ]]; then
        cd -- "$1"
    else
        cd -- "$(dirname -- "$1")"
    fi
}

# Helper function. Expands a list of strings such as 'foo', 'bar', 'baz' into
# the glob pattern **/*foo*/**/*bar*/**/*baz*, meaning it would match e.g.
# afoo/d/bara/baz, and stores the matching file names in the array g_files. If
# no files match, g_files becomes empty. If no arguments are supplied, **/* is
# used as the pattern.

_super_glob() {
    local pattern

    if [[ $# -eq 0 ]]; then
        pattern=**/*
    else
        pattern=**/*$1*
        shift
        for p in "$@"; do
            pattern=$pattern/**/*$p*
        done
    fi

    IFS=
    shopt -s nocaseglob nullglob
    g_files=($pattern)
    shopt -u nocaseglob nullglob
    unset IFS
}

# Helper function. Passes its second to last argument to _super_glob() and lets
# the user pick a file with a 'select' if many files match (otherwise, picks
# the single matching file). The first argument is the select prompt to use.
# The chosen file is returned in g_selected_file, which is unset if no files
# match.

_super_glob_select_file() {
    local prompt=$1
    shift

    unset g_selected_file

    _super_glob "$@"

    [[ ${#g_files[@]} -eq 0 ]] && return

    if [[ ${#g_files[@]} -eq 1 ]]; then
        g_selected_file=${g_files[0]}
    else
        PS3=$prompt
        # The while loop keeps us going while the user presses enter or Ctrl-D,
        # making sure we get a selection.
        while [[ -z $g_selected_file ]]; do
            select g_selected_file in "${g_files[@]}"; do
                [[ -n $g_selected_file ]] && break
                echo "invalid choice" >&2
            done
        done
        unset PS3
    fi
}

# Searches for files matching a _super_glob() pattern and opens the selected
# file for editing.

e() {
    _super_glob_select_file "File to edit: " "$@"

    if [[ -z $g_selected_file ]]; then
        _err "no files found"
        return 1
    fi

    "$EDITOR" -- "$g_selected_file"
}

# Lists files matching a _super_glob() pattern.

f() {
    _super_glob "$@"
    if [[ ${#g_files[@]} -eq 0 ]]; then
        _err "no files found"
        return 1
    fi
    printf "%s\n" "${g_files[@]}"
}

# Searches recursively in files for lines that match a given pattern and lists
# them. Optionally limits the search to files whose names match any of a number
# of given patterns. Excludes .git folders.

g() {
    local pattern includes

    if [[ $# -eq 0 ]]; then
        _usage "<pattern> [<file pattern> ...] "
        return 1
    fi

    pattern=$1
    shift
    includes=("${@/#/--include=}")

    grep -Iinr --exclude-dir=.git "${includes[@]}" -- "$pattern" .
}

# Jumps to a file matching a _super_glob() pattern. For directories, cd's to
# the directory. For ordinary files, cd's to the containing directory.

j() {
    _super_glob_select_file "Where to jump: " "$@"

    if [[ -z $g_selected_file ]]; then
        _err "no files found"
        return 1
    fi

    _cd_to "$g_selected_file"
}

# Searches for files matching a _super_glob() pattern, jumps to the directory
# (like for j()), and then opens the file for editing.

je() {
    _super_glob_select_file "File to jump to and edit: " "$@"

    if [[ -z $g_selected_file ]]; then
        _err "no files found"
        return 1
    fi

    _cd_to "$g_selected_file"
    "$EDITOR" -- "$(basename -- "$g_selected_file")"
}

# Creates a directory if it does not exist and jumps to it.

mcd() {
    if [[ $# -ne 1 ]]; then
        _usage "<dir>"
        return 1
    fi

    mkdir -p -- "$1" && cd -- "$1"
}

# Creates a timestamped tar.bz2 archive.

make_archive() {
    if [[ $# -lt 2 ]]; then
        _usage "<archive basename> <file> [<file> ...]"
        return 1
    fi

    tar cj --force-local --file="$1-$(date +%F-%H-%M-%S).tar.bz2" -- "${@:2}"
}

# Prints files and directories (non-recursively) in 'directory' (default '.')
# sorted by size.

big() {
    if [[ $# -gt 1 ]]; then
        _usage "[<directory>]"
        return 1
    fi

    shopt -s dotglob
    du -chs -- "${1-.}"/* | sort -h
    shopt -u dotglob
}

# Compiles a C/++ program from a single file with -Wall. Produces a debugging
# executable with no suffix and an optimized -O3 executable with an _opt
# suffix.

# TODO: Factor out compiler determination.

c() {
    local compiler file warn_opts

    if [[ $# -ne 1 ]]; then
        _usage "<source file>"
        return 1
    fi
    file=$1
    if [[ ! -e $file ]]; then
        _err "'$file' does not exist"
        return 1
    fi

    case $file in
        *.cpp ) compiler=g++ ;;
        *.c   ) compiler=gcc ;;
        *     )
            _err "unknown language for '$file'"
            return 1
            ;;
    esac

    warn_opts="-Wall -Wno-unused-variable -Wno-unused-but-set-variable"

    "$compiler" -o "${file%.*}" -ggdb3 $warn_opts "$file" && \
      "$compiler" -o "${file%.*}_opt" -O3 $warn_opts "$file"
}

# Compiles a C/++ program debugging executable from a single file with -Wall
# and runs it.

r() {
    local compiler file

    if [[ $# -eq 0 ]]; then
        _usage "<source file> [<argument> ...]"
        return 1
    fi
    file=$1
    if [[ ! -e $file ]]; then
        _err "'$file' does not exist"
        return 1
    fi

    case $file in
        *.cpp ) compiler=g++ ;;
        *.c   ) compiler=gcc ;;
        *     )
            _err "unknown language for '$file'"
            return 1
            ;;
    esac

    "$compiler" -o "${file%.*}" -ggdb3 -Wall -Wno-unused-variable "$file" && \
      ./"${file%.*}" "${@:2}"
}

# Suppress the GDB introductory and copyright message

alias gdb="gdb -q"
alias cgdb="cgdb -q"

# Creates a tags file in the current directory for the standard include
# directories

make_include_tags() {
    if [[ $# -gt 0 ]]; then
        _usage "(no arguments)"
        return 1
    fi

    # Include filenames, qualified names, and declarations. Treat filenames
    # with no extension or a .tcc extension as C++ headers. Exclude Qt stuff
    # and C++ stuff from old libstdc++ versions. Use line numbers (-n) as
    # system headers seldom change.
    ctags --langmap=c++:+..tcc -h+..tcc \
          --extra=fq --c++-kinds=+p \
          -I_GLIBCXX_VISIBILITY+ \
          -n --links=no \
          --exclude='*c++/4.5*' --exclude='*/qt4/*' \
          -R /usr/include /usr/local/include
}

# Share history between sessions
# (http://stackoverflow.com/questions/103944/real-time-history-export-amongst-bash-terminal-windows)

export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, don't overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

LESS=-
LESS+=F # Do not use pager if output fits on screen
LESS+=i # Case-insensitive search when only lowercase characters are used
LESS+=M # Be verbose (show percentage, etc.)
LESS+=R # Show ANSI colors
# Do not send termcap initialization/deinitialization codes. Fixes background
# screwiness in 'less' after using 256-color color schemes in Vim for some
# reason.
LESS+=X
LESS+=x4 # Display tabs as 4 spaces
export LESS

# Functions for inspecting compiler output

_asm() {
    local compiler

    if [[ $# -ne 3 ]]; then
        _usage "<filename>" 2
        return 1
    fi

    local prefix=$1
    local options=$2
    local file=$3

    local ofile=/tmp/${file%.cpp}.o

    if [[ ! -e $file ]]; then
        _err "'$file' does not exist" 2
        return 1
    fi

    case $file in
        *.cpp ) compiler=g++ ;;
        *.c   ) compiler=gcc ;;
        *     )
            _err "unknown language for '$file'" 2
            return 1
            ;;
    esac

    "$prefix$compiler" -o "$ofile" -c -ggdb3 $options "$file" || return $?
    if [[ ! -e $ofile ]]; then
        _err "no '$ofile' generated by $compiler. Aborting." 2
        return 1
    fi
    "$prefix"objdump -M intel-mnemonic -Cd "$ofile"
    command rm -- "$ofile"
}

asm() {
    _asm "" "-O3 -fomit-frame-pointer" "$@"
}

asm_noopt() {
    _asm "" "-O0" "$@"
}

armasm() {
    _asm "arm-none-eabi-" "-O3 -mthumb -mcpu=cortex-a8 -fomit-frame-pointer" "$@"
}

armasmnothumb() {
    _asm "arm-none-eabi-" "-O3 -mcpu=cortex-a8 -fomit-frame-pointer" "$@"
}

# Trace file access by a program. Prints the trace separately after the
# program's output once it has terminated.

files() {
    local tracefile

    if [[ $# -eq 0 ]]; then
        _usage "<program> [<argument> ...]"
        return 1
    fi

    if ! _prg_exists "$1"; then
        _err "found no program called '$1'"
        return 1
    fi

    tracefile=$(mktemp)
    strace -e trace=file -f -o "$tracefile" -- "$@"

    # Print the trace output after the regular output and remove some common
    # clutter
    echo -e "\nTrace:\n"
    egrep -v                     \
          -e '/etc/ld\.so'       \
          -e '/lib/'             \
          -e '/proc/filesystems' \
          -e '/usr/share/locale' \
          -e 'statfs.*selinux' < "$tracefile"

    command rm -- "$tracefile"
}

# Show where a shell function is defined. 'declare -F' can be used to list
# functions.

floc() {
    local error

    if [[ $# -ne 1 ]]; then
        _usage "<function name>"
        return 1
    fi

    shopt -s extdebug
    declare -F -- "$1"
    error=$?
    [[ $error -ne 0 ]] && _err "no function called '$1' defined"
    shopt -u extdebug
    return $error
}

complete -A function floc

# Git {{{

alias ga="git add -u"
alias gc="git checkout"
alias gd="git diff"
alias gds="git diff --stat"
alias gdc="git diff --cached"
alias gdcs="git diff --cached --stat"
alias gl="git log"
alias glp="git log -p"
alias gls="git log --stat"
alias gp="git pull --rebase"
alias gs="git status"

alias discard="git reset --hard HEAD"

alias amend="git commit --amend"
# Adds changes to tracked files to the branch's tip commit
alias fixup="git commit -a --amend -C HEAD"

# Checks if a file is in the repository

i() {
    if [[ $# -ne 1 ]]; then
        _usage "<filename>"
        return 1
    fi

    if git ls-files --error-unmatch -- "$1" &>/dev/null; then
        echo -n yes
    else
        echo -n no
    fi
    [[ -e $1 ]] || echo -n " (non-existent)"
    echo
}

# Prints the branch tracked by a branch together with the remote and its URL.
# Without arguments, defaults to the current branch.

upstream() {
    local branch remote_branch remote remote_url

    if [[ $# -gt 1 ]]; then
        _usage "[<branch>] (defaults to current branch)"
        return 1
    fi

    if ! git rev-parse --git-dir &>/dev/null; then
        _err "not inside a Git repository"
        return 1
    fi

    if [[ -z $1 ]]; then
        if ! branch=$(git symbolic-ref HEAD 2>/dev/null); then
            _err "failed to get branch for HEAD (detached?)"
            return 1
        fi
    else
        branch=$1
    fi
    branch=${branch#refs/heads/}

    if ! git show-ref --verify -q "refs/heads/$branch"; then
        _err "no branch named '$branch'"
        return 1
    fi

    remote_branch=$(git config "branch.$branch.merge") || remote_branch="(no upstream)"
    remote_branch=${remote_branch#refs/heads/}
    if remote=$(git config "branch.$branch.remote"); then
        remote_url=" ($(git config "remote.$remote.url"))" || \
            remote_url=" (could not get the remote's URL)"
    else
        remote="(no remote)"
        remote_url=
    fi

    # Avoid printing any unnecessary extra spaces
    echo $remote_branch @ ${remote}$remote_url
}

# Fetches a single branch and its objects from a remote and sets it up as a
# tracking branch. With no name given, uses the name of the remote branch for
# the local branch.

fetch() {
    local remote remote_branch local_branch error

    if [[ $# -eq 0 || $# -gt 3 ]]; then
        _usage "<remote> <remote branch> [<local branch>]"
        return 1
    fi

    remote=$1
    remote_branch=$2
    local_branch=${3-$remote_branch}

    git fetch "$remote" "+$remote_branch:$local_branch" || return $?
    if ! git show-ref --verify -q "refs/heads/$local_branch"; then
        _err "no local branch '$local_branch' was created"
        return 1
    fi

    git branch --set-upstream "$local_branch" "remotes/$remote/$remote_branch"
    error=$?
    if [[ $error -ne 0 ]]; then
        _err "failed to set '$remote_branch' on '$remote' as the upstream of '$local_branch'"
        return $error
    fi
}

# }}}

# Terminals, prompts and colors

_init_terminals_and_prompts_and_colors() {
    # Use the true/false shell builtins to create booleans
    local is_xterm=false
    local has_256_colors=false

    case $TERM in
        # Assume that all terminals that identify themselves as either "xterm"
        # or "xterm-256color" support 256 colors. This could be refined.
        xterm | xterm-256color )
            # Some terminal apps (e.g. Vim) check for this
            export TERM=xterm-256color
            is_xterm=true
            has_256_colors=true
            ;;
        rxvt-*256color )
            has_256_colors=true
            ;;
    esac

    # Helper function for displaying the current Git branch in the Bash prompt

    _where() {
        local branch
        branch=$(git symbolic-ref HEAD 2>/dev/null) || return
        echo -n "${branch#refs/heads/} "
    }

    # Resets all color settings
    local r='\[\033[0m\]'

    if $has_256_colors; then
        # See the following for reference:
        # http://lucentbeing.com/blog/that-256-color-thing/
        # http://jimlund.org/blog/?p=130

        # Changes the foreground color for 256-color mode
        _c() { echo -n '\[\033[38;05;'$1'm\]'; }

        PS1="$(_c 46)\u $(_c 214)\h $(_c 39)\w $(_c 46)\$(_where)$r$ "
    else
        # Changes the foreground color for 8-color mode; 0-7 corresponds to
        # black, red, green, yellow, blue, magenta, cyan, and white, in that
        # order.
        _c() { echo -n '\[\033[3'$1'm\]'; }

        PS1="$(_c 2)\u $(_c 3)\h $(_c 4)\w $(_c 2)$(_where)$r$ "
    fi

    # For xterm, display the current working directory and username/host in the
    # window title bar
    $is_xterm && PS1="\[\033]0;\w   \u \h\007\]$PS1"
}

_init_terminals_and_prompts_and_colors

# Site-specific settings

_local_settings_file=~/conf/bashlocal

[[ -e $_local_settings_file ]] && . "$_local_settings_file"
