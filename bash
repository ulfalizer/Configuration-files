#!/bin/bash

# This file is meant to be included from the main Bash configuration file

# Reload configuration
alias r=". ~/conf/bash"

# Misc. aliases

alias -- -="cd - >/dev/null"
# autocd would also take care of '..', but the alias avoids the annoying
# "cd .." printout
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias ll="ls -l"

# Preference variables

export EDITOR=vim

# General shell options

if (( ${BASH_VERSINFO[0]} >= 4 )); then
    shopt -s autocd
    shopt -s globstar
fi

# Safe rm command with trash directory

trash_dir=/tmp/trash

alias rm=rm_fn

rm_fn() {
    local error

    if [[ $# -eq 0 ]]; then
        echo "usage: rm <file> [<file> ...]" 1>&2
        return 1
    fi

    if [[ -z $trash_dir ]]; then
        echo "trash_dir not set" 1>&2
        return 1
    fi

    for f in "$@"; do
        if [[ ! -e $f && ! -h $f ]]; then
            echo "'$f' does not exist" 1>&2
            return 1
        fi
        if [[ ! -w $(dirname -- "$f") ]]; then
            echo "Cannot remove '$f': No write permissions for containing directory" 1>&2
            return 1
        fi
    done

    if [[ -e $trash_dir && ! -d $trash_dir ]]; then
        echo "'$trash_dir' is not a directory" 1>&2
        return 1
    fi

    mkdir -p -- "$trash_dir"
    if [[ ! -e $trash_dir ]]; then
        echo "Failed to create '$trash_dir'" 1>&2
        return 1
    fi

    mv -f --backup=numbered -- "$@" "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        echo "Failed to move files into '$trash_dir'" 1>&2
        return $error
    fi
}

empty_trash() {
    local error

    if [[ -z $trash_dir ]]; then
        echo "trash_dir not set" 1>&2
        return 1
    fi

    [[ ! -e $trash_dir ]] && return

    if [[ ! -d $trash_dir ]]; then
        echo "'$trash_dir' is not a directory" 1>&2
        return 1
    fi

    if [[ ! -w $(dirname -- "$trash_dir") ]]; then
        echo "Cannot remove '$trash_dir': No write permissions for containing directory" 1>&2
        return 1
    fi

    command rm -rf -- "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        echo "Failed to remove '$trash_dir'" 1>&2
        return $error
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
# The choosen file is returned in g_selected_file, which is unset if no files
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
                if [[ -z $g_selected_file ]]; then
                    echo "Invalid choice" 1>&2
                else
                    break
                fi
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
        echo "no files found" 1>&2
        return
    fi

    $EDITOR -- "$g_selected_file"
}

# Lists files matching a _super_glob() pattern.

f() {
    _super_glob "$@"

    if [[ ${#g_files[@]} -eq 0 ]]; then
        echo "no files found" 1>&2
        return
    fi

    for f in "${g_files[@]}"; do
        echo $f
    done
}

# Searches recursively in files for lines that match a given pattern and lists
# them. Optionally limits the search to files whose names match any of a number
# of given patterns. Excludes .git folders.

g() {
    local pattern includes

    if [[ $# -eq 0 ]]; then
        echo "usage: gr <pattern> [<file pattern> ...] " 1>&2
        return 1
    fi

    pattern=$1
    shift
    includes=("${@/#/--include=}")

    grep -Iinr --exclude-dir=.git "${includes[@]}" -- "$pattern" .
}

# Jumps to a file matching a _super_glob() pattern. (For directories, cd's to
# the directory. For ordinary files, cd's to the containing directory.)

j() {
    _super_glob_select_file "Where to jump: " "$@"

    if [[ -z $g_selected_file ]]; then
        echo "no files found" 1>&2
        return
    fi

    # If $file is a directory, jump to it. Otherwise, jump to the directory
    # containing $file.

    if [[ -d $g_selected_file ]]; then
        cd -- "$g_selected_file"
    else
        cd -- "$(dirname -- "$g_selected_file")"
    fi
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

# Helper functions for inspecting compiler output

asm_() {
    local prefix=$1
    local options=$2
    local file=$3

    local ofile=/tmp/${file%.cpp}.o

    if [[ ! -e $file ]]; then
        echo "'$file' does not exist" 1>&2
        return 1
    fi

    ${prefix}g++ $options "$file" -c -o "$ofile" || return $?
    if [[ ! -e $ofile ]]; then
        echo "No '$ofile' generated by g++. Aborting." 1>&2
        return 1
    fi
    ${prefix}objdump -d "$ofile"
    command rm "$ofile"
}

asm() {
    asm_ "" "-O3 -fomit-frame-pointer" "$1"
}

armasm() {
    asm_ "arm-none-eabi-" "-O3 -mthumb -mcpu=cortex-a8 -fomit-frame-pointer" "$1"
}

armasmnothumb() {
    asm_ "arm-none-eabi-" "-O3 -mcpu=cortex-a8 -fomit-frame-pointer" "$1"
}

# Trace file access by a program

files() {
    local tracefile

    if [[ $# -eq 0 ]]; then
        echo "usage: files <program> [<argument> ...]" 1>&2
        return 1
    fi

    tracefile=$(mktemp)
    strace -e trace=file -f -o $tracefile -- "$@"

    # Print the trace output after the regular output and remove some common
    # clutter
    echo -e "\nTrace:\n"
    egrep -v                     \
          -e '/etc/ld\.so'       \
          -e '/lib/'             \
          -e '/proc/filesystems' \
          -e '/usr/share/locale' \
          -e 'statfs.*selinux' < $tracefile

    command rm $tracefile
}

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
        echo "usage: i <filename>" 1>&2
        return 1
    fi

    if git ls-files --error-unmatch -- "$1" &>/dev/null; then
        echo -n yes
    else
        echo -n no
    fi
    [[ ! -e $1 ]] && echo -n " (non-existent)"
    echo
}

# Prints the branch tracked by a branch together with the remote and its URL.
# Without arguments, defaults to the current branch.

upstream() {
    local branch remote_branch remote remote_url

    if [[ $# -gt 1 ]]; then
        echo "usage: upstream [<branch>] (defaults to current branch)" 1>&2
        return 1
    fi

    if ! git rev-parse --git-dir &>/dev/null; then
        echo "Not inside a Git repository" 1>&2
        return 1
    fi

    if [[ -z $1 ]]; then
        if ! branch=$(git symbolic-ref HEAD 2>/dev/null); then
            echo "Failed to get branch for HEAD (detached?)" 1>&2
            return 1
        fi
    else
        branch=$1
    fi
    branch=${branch#refs/heads/}

    if ! git show-ref --verify -q "refs/heads/$branch"; then
        echo "No branch named '$branch'" 1>&2
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
        echo "usage: fetch <remote> <remote branch> [<local branch>]" 1>&2
        return 1
    fi

    remote=$1
    remote_branch=$2
    local_branch=${3-$remote_branch}

    git fetch "$remote" "+$remote_branch:$local_branch" || return $?
    if ! git show-ref --verify -q "refs/heads/$local_branch"; then
        echo "No local branch '$local_branch' was created" 1>&2
        return 1
    fi

    git branch --set-upstream "$local_branch" "remotes/$remote/$remote_branch"
    error=$?
    if [[ $error -ne 0 ]]; then
        echo "Failed to set '$remote_branch' on '$remote' as the upstream of '$local_branch'" 1>&2
        return $error
    fi
}

# Helper for displaying the current Git branch in the Bash prompt

where() {
    local branch
    branch=$(git symbolic-ref HEAD 2>/dev/null) || return
    echo -n "${branch#refs/heads/} "
}

# }}}

# Colors and prompts

# Use the true/false shell builtins to create booleans
is_xterm=false
has_256_colors=false

case $TERM in
    # Assume that all terminals that identify themselves as either "xterm" or
    # "xterm-256color" support 256 colors. This could be refined.
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

if $has_256_colors; then
    # See the following for reference:
    # http://lucentbeing.com/blog/that-256-color-thing/
    # http://jimlund.org/blog/?p=130

    # Changes the foreground color
    C() { echo -n '\[\033[38;05;'${1}m'\]'; }
    # Resets all color settings
    R='\[\033[0m\]'

    PS1="$(C 46)\u $(C 214)\h $(C 39)\w $(C 46)\$(where)$R$ "
else
    # TODO: This could use 8 colors
    PS1='\u \h \w $(where)$ '
fi

# For xterm, display the current working directory and username/host in the
# window title bar
if $is_xterm; then
    PS1="\[\033]0;\w   \u \h\007\]$PS1"
fi

# Site-specific settings

if [[ -e ~/conf/bashlocal ]]; then
    . ~/conf/bashlocal
fi
