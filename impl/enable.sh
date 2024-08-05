#!/bin/bash

# get some variables
dirOfThisScript="$(cd $(dirname $BASH_SOURCE) && pwd)"
repoRoot="$(cd "$dirOfThisScript/.." && pwd)"
#echo dir of this script is "'$dirOfThisScript'"
#echo repo root is "$repoRoot"
#echo bash source zero is "$BASH_SOURCE"

# Make a function for calling SessionManager
function ses() {
  "$repoRoot/SessionManager.sh" "$@"
}

# Choose a window id if none is already chosen.
# SessionManager uses this to determine which session is open.
if [ "$SESSION_WINDOW" == "" ]; then
  export SESSION_WINDOW="$(ses newWindowId)"
fi

# Inform SessionManager when we run a command
PS0='$(ses executing $(history 1 | sed "s/ *[0-9][0-9]*//"))'

# Show the session in the prompt
PS1="\[\e[32m\]\w\[\e[33m\] \$(ses name)\[\e[0m\] \$ "
