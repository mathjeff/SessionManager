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

# Show the session in the prompt
PS1="\[\e[32m\]\w\[\e[33m\] \$(ses name)\[\e[0m\] \$ "

# Inform SessionManager about changes to the history
latestSessionHistory=""
function updateSessionHistory() {
  # This gives us the latest command that the user ran, plus a number in front telling the command number
  newSessionHistory="$(history 1)"
  #echo "Latest history: $newSessionHistory"
  # This function may get called more often than the user types individual commands:
  #  If the user uses PROMPT_COMMAND, then it might be called whenever one of those commands runs
  #  If the user uses '&&' to run multiple commands consecutively, this function might run for each of those commands
  # So, we only update the history if the command has changed
  if [ "$newSessionHistory" != "$latestSessionHistory" ]; then
    #echo "New history: '$newSessionHistory'"
    latestSessionHistory="$newSessionHistory"
    # Remove the command number and pass the rest to SessionManager
    ses executing "$(echo "$newSessionHistory" | sed 's/ *[0-9][0-9]* *//')"
  fi
}
# Whenever we run a command, we consider updating SessionManager about changes to the history
# It would be simpler to just run this function in PS0, but that doesn't seem to work on Mac
trap updateSessionHistory DEBUG
