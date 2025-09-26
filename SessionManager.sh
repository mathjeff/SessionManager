#!/bin/bash
set -e

function usage() {
  echo "
SessionManager: save and recall information to and from sessions

Usage: SessionManager.sh <command> [<arguments>]

  User commands that don't require a session

    ac
    active
      Lists names of all active sessions

    new <name> [--all]
      Create a new session named <name>
      If --all is specified, all windows are attached to the session named <name>

    at     <name> [--all]
    attach <name> [--all]
      Attaches to the session named <name>
      If --all is specified, all windows are attached to the session named <name>

    aat <name>
      Short for 'at <name> --all'

    res     <sessionName>
    resolve <sessionName>
      Mark session <sessionName> as resolved, so it will no longer appear in the output of 'ses ac'
      If <sessionName> is unspecified, the current session will be resolved instead

  User commands that run within a session

    hist    [-d] [-u] [-v] [-a] [-g <regex>] [<count>]
    history [-d] [-u] [-v] [-a] [-g <regex>] [<count>]
      View a history of the last <count> commands (default 10) run in the current session
      -d: Only show commands that were run in the current directory
      -u: Don't output the same line more than once
      -v: Also output the timestamp and working directory of each command
      -a: Also include commands run in other sessions
      -g: Only report results matching the given regex

    dirs [<count>]
      View the last <count> (default 10) working directories of commands in this session

    notes
      Open session-specific notes

    alias
      Lists all aliases created in this session

    alias <name>
      Shows the content of alias <name>

    alias <name> <command>
      Makes an alias named <name> that can be run later

    run <name>
      Runs alias <name>

    analyze [<sessionName>]
      Outputs commands that tend to take a long time in the given session (the current session by default)

    det    [--all]
    detach [--all]
      Detach from the current session

  Data location

    Data is stored in $HOME/sessionData by default
    To change this directory, set the SESSION_MANAGER_HOME environment variable to the desired directory

  Scripting hooks that aren't intended for users to interact with directly

    name
      Output the name of the session

    newWindowId
      Chooses a new identifier for a new window
      The caller should save this information in the SESSION_WINDOW environment variable

    executing <arguments>
      Declares that the given command is executing and should be added to the history

"

  exit 1
}

dirOfThisFile="${0//\/SessionManager.sh/}"
#dataDir="$dirOfThisFile/../sessions"
if [ "$SESSION_MANAGER_HOME" == "" ]; then
  SESSION_MANAGER_HOME="$HOME/sessionData"
fi
dataDir="$SESSION_MANAGER_HOME"
sessionsDir="$dataDir/sessions"
windowsDir="$dataDir/windows"

command="$1"

if [ "$command" == "newWindowId" ]; then
  # choose window id
  when="$(date +%s)"
  numberOfWindows="$(ls $windowsDir 2>/dev/null | wc -l | grep -o '[0-9][0-9]*')"
  newWindowId="${when}_${numberOfWindows}"
  echo "$newWindowId"
  # also make a directory for this window
  windowDir="$windowsDir/$newWindowId"
  mkdir -p "$windowDir"
  touch "$windowDir/sessionName"

  exit
fi

windowId="$SESSION_WINDOW"
if [ "$windowId" == "" ]; then
  echo "WindowId unset: run export SESSION_WINDOW=\$(sessionManager.sh newWindowId)"
  exit 1
fi
windowDir="$windowsDir/$windowId"

sessionName="$(cat $windowDir/sessionName 2>/dev/null || true)"
if [ "$sessionName" == "" ]; then
  sessionName="unset"
fi

if [ "$command" == "name" ]; then
  echo $sessionName
  exit
fi

function getSessionDir() {
  forSessionName="$1"
  echo "${sessionsDir}/${forSessionName}"
}
sessionDir="$(getSessionDir $sessionName)"

shift || true

if [ "$command" == "executing" ]; then
  historyFile="${sessionDir}/history"
  if [ ! -e "${historyFile}" ]; then
    mkdir -p "$(dirname ${historyFile})"
  fi
  echo "$PWD $(date +%Y-%m-%dT%H:%M:%S) $*" >> "${historyFile}"
  exit
fi

# Code above here might run as part of the command prompt so we'd like it to be extra fast
# Code after here should only run when the user explicitly calls it, so it doesn't need to be as fast

if [ "$command" == "active" -o "$command" == "ac" ]; then
  activeSessionsFile="${dataDir}/activeSessions"
  if [ ! -f "$activeSessionsFile" ]; then
    touch "$activeSessionsFile"
  fi
  cat "$activeSessionsFile"
  exit
fi

function stringMatch() {
  stringSelector="$1"
  choices="$2"
  matches="$(echo "$choices" | sed 's/ /\n/g' | grep "$stringSelector")"
  echo "$matches"
}

function chooseString() {
  selector="$1"
  choices="$2"
  outputErrorMessage="$3"
  if [ "$outputErrorMessage" == "true" ]; then
    outputUniqueMatch="false"
  else
    outputUniqueMatch="true"
  fi

  # selectors from most to least specific
  selectors="^${selector}$ ^${selector} ${selector}"

  latestUnmatched=""
  for matcher in $selectors; do
    match="$(stringMatch "$matcher" "$choices")"
    if echo "$match" | xargs echo | grep " " > /dev/null; then
      # multiple matches
      if [ "$outputErrorMessage" == "true" ]; then
        echo "Multiple matches for $matcher found:"
        echo $match | sed 's/ /\n/g'
        return 1
      fi
      return 0
    fi
    if [ "$match" == "" ]; then
      if [ "$outputErrorMessage" == "true" ]; then
        latestUnmatched="$matcher"
      fi
      continue
    fi
    if [ "$outputUniqueMatch" == "true" ]; then
      echo "$match"
    fi
    return 0
  done
  if [ "$outputErrorMessage" == "true" ]; then
    echo "No match for $latestUnmatched"
    return 1
  fi
  return 0
}

function setSessionName() {
  # process parameters
  sessionNameQuery="$1"
  actionType="$2" # create, autocomplete
  if [ "$actionType" == "autocomplete" ]; then
    candidates="$(ls "$sessionsDir" | grep "$newSessionName" || true)"
    newSessionName="$(chooseString "$sessionNameQuery" "$candidates" false)"
    if [ "$newSessionName" == "" ]; then
      # report error and return
      chooseString "$sessionNameQuery" "$candidates" "true"
      return
    fi
  else
    newSessionName="$sessionNameQuery"
  fi

  mkdir -p "${windowDir}"
  # update session name
  sessionNameFile="${windowDir}/sessionName"
  echo "$newSessionName" > "${sessionNameFile}"
  newSessionDir="$(getSessionDir $newSessionName)"
  mkdir -p "$newSessionDir"

  # add to list of active sessions
  if [ "$newSessionName" != "unset" ]; then
    activeSessionsFile="${dataDir}/activeSessions"
    tempFile="${activeSessionsFile}.temp"
    cp "$activeSessionsFile" "$tempFile" 2>/dev/null || true
    echo "$newSessionName" >> "$tempFile"
    sort "$tempFile" | uniq | grep -v "^$" > "${activeSessionsFile}"
    rm -f "$tempFile"
  fi
  sessionName="$newSessionName"
}

function setAllWindowsSessionName() {
  newSessionName="$1"

  # remove old window metadata so we don't have to keep updating it every time we call this function
  removeOldWindowData

  # update session name for other windows
  echo "$newSessionName" | tee $windowsDir/*/sessionName >/dev/null
}

function removeOldWindowData() {
  oldWindows="$(ls $windowsDir | head -n -16)"
  if [ "$oldWindows" != "" ]; then
    echo "Removing old windows metadata in $windowsDir"
    numRemoved=0
    for removeDir in $oldWindows; do
      removeDir="$windowsDir/$removeDir"
      if [ -e "$removeDir" ]; then
        echo "Removing old window metadata $removeDir"
        rm -rf "$removeDir"
        numRemoved="$(($numRemoved + 1))"
      else
        echo "Error: couldn't find $removeDir"
        exit 1
      fi
    done
    echo "Removed $numRemoved old windows metadata in $windowsDir"
  fi
}

if [ "$command" == "new" ]; then
  newSessionName="$1"
  setSessionName "$newSessionName"
  if [ "$2" == "--all" ]; then
    setAllWindowsSessionName "$sessionName"
  fi
  exit
fi

if [ "$command" == "detach" -o "$command" == "det" ]; then
  newSessionName="unset"
  if [ "$1" == "--all" ]; then
    setAllWindowsSessionName "$newSessionName"
  else
    setSessionName "$newSessionName"
  fi
  exit
fi

if [ "$command" == "alias" ]; then
  scriptsDir="${sessionDir}/scripts"
  aliasName="$1"
  if [ "$aliasName" == "" ]; then
    # list aliases
    echo "Aliases in this session:"
    if [ -e "$scriptsDir" ]; then
      bash -c "cd $scriptsDir && ls *.sh | sed 's/\.sh//'"
    else
      echo "None found."
    fi
  else
    aliasPath="${scriptsDir}/${aliasName}.sh"
    aliasContent="$2"
    if [ "$aliasContent" == "" ]; then
      # show this alias
      echo "Alias $aliasName at $aliasPath:"
      cat "$aliasPath"
    else
      # write this alias
      mkdir -p "$scriptsDir"
      echo "$aliasContent" > "$aliasPath"
      chmod u+x "$aliasPath"
      echo "Wrote $aliasPath"
    fi
  fi
  exit
fi

if [ "$command" == "run" ]; then
  scriptsDir="${sessionDir}/scripts"
  aliasName="$1"
  if [ "$aliasName" == "" ]; then
    # list aliases
    echo "Aliases in this session:"
    if [ -e "$scriptsDir" ]; then
      bash -c "cd $scriptsDir && ls *.sh | sed 's/\.sh//'"
    else
      echo "None found."
    fi
  else
    aliasPath="${scriptsDir}/${aliasName}.sh"
    bash -c "$aliasPath"
  fi
  exit
fi

if [ "$command" == "attach" -o "$command" == "at" -o "$command" == "aat" ]; then
  newSessionName="$1"
  setSessionName "$newSessionName" autocomplete
  if [ "$2" == "--all" -o "$command" == "aat" ]; then
    setAllWindowsSessionName "$sessionName"
  fi
  exit
fi

# Resolves the given path to a full path that can be used by the operating system
# This currently only has an effect in Cygwin
function resolvePath() {
  path="$1"
  if type cygpath >/dev/null 2>/dev/null; then
    cygpath -w "$path"
  else
    echo "$path"
  fi
}

function analyzeSession() {
  analyzeSessionName="$1"

  analysisScriptDir="$dirOfThisFile/impl"
  analysisScript="$analysisScriptDir/analyze-history.sh"
  historyFile="$sessionsDir/$analyzeSessionName/history"
  relativeHistoryFile="$(resolvePath "$historyFile")"
  "$analysisScript" "$relativeHistoryFile"
}

if [ "$command" == "resolve" -o "$command" == "res" ]; then
  resolveSessionName="$1"

  if [ "$resolveSessionName" == "" ]; then
    echo "Detaching from current session"
    resolveSessionName="$sessionName"
    setSessionName unset
  fi
  analyzeSession "$resolveSessionName"
  activeSessionsFile="${dataDir}/activeSessions"
  tempFile="${activeSessionsFile}.temp"
  grep -v "^${resolveSessionName}" "$activeSessionsFile" > "$tempFile"
  mv "$tempFile" "$activeSessionsFile"
  echo "Resolved session $resolveSessionName"
  exit
fi

if [ "$command" == "notes" ]; then
  notesPath="${sessionDir}/notes"
  vi ${notesPath}
  exit
fi

if [ "$command" == "hist" -o "$command" == "history" ]; then
  requireSameDir=false
  removeDuplicates=false
  verbose=false
  includeAllSessions=false
  length=10
  filter=

  while [ "$1" != "" ]; do
    arg="$1"
    shift
    if [ "$arg" == "-d" ]; then
      requireSameDir=true
      continue
    fi
    if [ "$arg" == "-u" ]; then
      removeDuplicates=true
      continue
    fi
    if [ "$arg" == "-v" ]; then
      verbose=true
      continue
    fi
    if [ "$arg" == "-a" ]; then
      includeAllSessions=true
      continue
    fi
    if [ "$arg" == "-g" ]; then
      filter="$1"
      shift
      continue
    fi
    length="$arg"
  done
  if [ "$includeAllSessions" == "true" ]; then
    sessionNames="*"
  else
    sessionNames="$sessionName"
  fi
  historyFiles="$(ls ${sessionsDir}/${sessionNames}/history | xargs echo)"
  for filename in $historyFiles; do
    histCommand="cat $filename"
    if [ "$requireSameDir" == "true" ]; then
      histCommand="$histCommand | grep '$PWD '"
    fi
    if [ "$verbose" == "false" ]; then
      histCommand="$histCommand | sed 's/^\([^ ]*\) \([^ ]*\) //'"
    fi
    if [ "$filter" != "" ]; then
      histCommand="$histCommand | grep '$filter'"
    fi
    if [ "$removeDuplicates" == "true" ]; then
      histCommand="$histCommand | $dirOfThisFile/impl/latest-uniq.sh"
    fi
    if [ "$length" != "" ]; then
      histCommand="$histCommand | tail -n $length"
    fi
    # add a title if results are nonempty
    histCommand="$histCommand | $dirOfThisFile/impl/title.sh '
In ${filename}:'"
    bash -c "$histCommand" || true
  done
  exit
fi


if [ "$command" == "dirs" ]; then
  count="$1"
  if [ "$count" == "" ]; then
    count="10"
  fi
  historyFile="$sessionsDir/$sessionName/history"

  echo "Last $count unique directories in ${sessionName}:"
  cat "$historyFile" | sed 's/ .*//' | "$dirOfThisFile/impl/latest-uniq.sh" | tail -n "$count"
  exit
fi

if [ "$command" == "analyze" ]; then
  analyzeSessionName="$1"
  if [ "$analyzeSessionName" == "" ]; then
    analyzeSessionName="$sessionName"
  fi
  analyzeSession "$analyzeSessionName"
  exit
fi

# didn't find a command
usage
