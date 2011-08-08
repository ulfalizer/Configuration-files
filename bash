# This file is meant to be included from the main Bash configuration file

alias ll="ls -l"

alias vimrc="vim ~/.vimrc"
alias bashrc="vim ~/conf/bash"
alias gitconfig="vim ~/conf/gitconfig"

# See http://www.chiark.greenend.org.uk/~sgtatham/aliases.html

noglob_helper() {
    "$@"
    case "$shopts" in
        *noglob*) ;;
        *) set +f ;;
    esac
    unset shopts
}

e() { vim $(find . -iname "$1"); }

gr_fn() {
    if [[ $# -eq 0 ]]; then
        echo "usage: gr <pattern> [<file pattern> ...] " 1>&2
        return 1
    fi

    pattern="$1"
    shift
    includes=("${@/#/--include=}")

    grep -Inr --exclude-dir=.git "${includes[@]}" "$pattern" .
}

alias gr='shopts="$SHELLOPTS"; set -f; noglob_helper gr_fn'

# Share history between sessions
# (http://stackoverflow.com/questions/103944/real-time-history-export-amongst-bash-terminal-windows)

export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, don't overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Make searches in 'less' case-insensitive and enable color output
export LESS=-iRx4

# Git {{{

alias gb="git branch"
alias gl="git log"
alias gs="git status -s"

# Checks if a file is in the repository

function i {
	if git ls-files --error-unmatch "$1" &>/dev/null; then
		echo yes
	else
		echo no
	fi
}

# Display the current git branch in the Bash prompt

function where {
	branch=$(git symbolic-ref HEAD 2>/dev/null)
	if [[ $? != 0 ]]; then
		return
	fi
	echo -n "(${branch#refs/heads/})"
}

# Requires a color terminal
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;32m\]$(where)\[\033[00m\]\$ '

# }}}
