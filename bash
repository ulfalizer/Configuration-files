#!/bin/bash

# This file is meant to be included from the main Bash configuration file

alias ll="ls -l"

# Safe rm command with trash directory

export trash_dir=/tmp/trash

alias rm=rm_fn

rm_fn() {
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
    done

    if [[ -e $trash_dir && ! -d $trash_dir ]]; then
        echo "$trash_dir is not a directory" 1>&2
        return 1
    fi

    mkdir -p -- "$trash_dir"
    if [[ ! -e $trash_dir ]]; then
        echo "Failed to create $trash_dir" 1>&2
        return 1
    fi

    mv --backup=numbered -- "$@" "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        echo "Failed to move files into $trash_dir" 1>&2
        return $error
    fi
}

empty_trash() {
    if [[ -z $trash_dir ]]; then
        echo "trash_dir not set" 1>&2
        return 1
    fi

    [[ ! -e $trash_dir ]] && return

    if [[ ! -d $trash_dir ]]; then
        echo "$trash_dir is not a directory" 1>&2
        return 1
    fi

    command rm -rf -- "$trash_dir"
    error=$?
    if [[ $error -ne 0 ]]; then
        echo "Failed to remove $trash_dir" 1>&2
        return $error
    fi
}

e() { vim $(find . -iname "$1"); }

f() {
    if [[ $# -ne 1 ]]; then
        echo "usage: f <filename>"
        return 1
    fi

    find . -iname "*$1*"
}

gr() {
    if [[ $# -eq 0 ]]; then
        echo "usage: gr <pattern> [<file pattern> ...] " 1>&2
        return 1
    fi

    pattern="$1"
    shift
    includes=("${@/#/--include=}")

    grep -Iinr --exclude-dir=.git "${includes[@]}" "$pattern" .
}

# Share history between sessions
# (http://stackoverflow.com/questions/103944/real-time-history-export-amongst-bash-terminal-windows)

export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, don't overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Make searches in 'less' case-insensitive and enable color output
export LESS=-iRMx4

export EDITOR=vim

# Helper functions for inspecting compiler output

asm_() {
    prefix="$1"
    options="$2"
    file="$3"
    ofile="/tmp/${1%.cpp}.o"

    if [[ ! -e "$file" ]]; then
        echo "'$file' does not exist" 1>&2
        return 1
    fi

    ${prefix}g++ $options "$file" -c -o "$ofile"
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

# Git {{{

alias ga="git add -u"
alias gc="git checkout"
alias gd="git diff"
alias gl="git log"
alias glp="git log -p"
alias gp="git pull --rebase"
alias gs="git status"

alias discard="git reset --hard HEAD"

# Checks if a file is in the repository

i() {
	if git ls-files --error-unmatch "$1" &>/dev/null; then
		echo yes
	else
		echo no
	fi
}

# Print the branch tracked by a branch. Without arguments, defaults to the
# current branch.

upstream() {
    if [[ -z $1 ]]; then
        branch=$(git symbolic-ref HEAD 2>/dev/null)
    else
        branch=$1
    fi
    branch=${branch#refs/heads/}

    if ! git show-ref --verify -q -- "refs/heads/$branch"; then
        echo "No branch named '$branch'" 1>&2
        return 1
    fi

    remote=$(git config "branch.$branch.remote") || remote="(no remote)"
    remote_branch=$(git config "branch.$branch.merge") || remote_branch="(no upstream)"
    remote_branch=${remote_branch#refs/heads/}

    echo $remote_branch @ $remote
}

# Display the current git branch in the Bash prompt

where() {
	branch=$(git symbolic-ref HEAD 2>/dev/null) || return
	echo -n "(${branch#refs/heads/})"
}

# Requires a color terminal
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;32m\]$(where)\[\033[00m\]\$ '

# }}}

# Site-specific settings

if [[ -e ~/conf/bashlocal ]]; then
    . ~/conf/bashlocal
fi
