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

    new <name>
      Create a new session named <name>

    at <name>
    attach <name>
      Attaches to the session named <name>

    res <sessionName>
    resolve <sessionName>
      Mark session <sessionName> as resolved, so it will no longer appear in the output of 'ses ac'

  User commands that run within a session

    hist [-d] [-u] [-v] [-a] [<count>]
      View a history of the last <count> commands (default 10) run in the current session
      -d: Only show commands that were run in the current directory
      -u: Don't output the same line more than once
      -v: Also output the timestamp and working directory of each command
      -a: Also include commands run in other sessions

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

    det
    detach
      Detach from the current session

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

dirOfThisFile="$(dirname $0)"
dataDir="$(cd $dirOfThisFile/.. && pwd)/sessions"
sessionsDir="$dataDir/sessions"
windowsDir="$dataDir/windows"

command="$1"
shift || true

if [ "$command" == "newWindowId" ]; then
  when="$(date +%s)"
  numberOfWindows="$(ls $windowsDir 2>/dev/null | wc -l | grep -o '[0-9][0-9]*')"
  echo "${when}_${numberOfWindows}"
  exit
fi

windowId="$SESSION_WINDOW"
if [ "$windowId" == "" ]; then
  echo "WindowId unset: run export SESSION_WINDOW=\$(sessionManager.sh newWindowId)"
  exit 1
fi
windowDir="${windowsDir}/${windowId}"

sessionName="$(cat ${windowDir}/sessionName 2>/dev/null || true)"
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

if [ "$command" == "active" -o "$command" == "ac" ]; then
  activeSessionsFile="${dataDir}/activeSessions"
  if [ ! -f "$activeSessionsFile" ]; then
    touch "$activeSessionsFile"
  fi
  cat "$activeSessionsFile"
  exit
fi

function uniqueStringMatch() {
  stringSelector="$1"
  choices="$2"
  # If true, output the value if it's unique - don't echo any errors
  # If false, output any errors - don't output the value
  outputIsError="$3"

  matches="$(echo "$choices" | sed 's/ /\n/g' | grep "$stringSelector")"
  if [ "$matches" == "" ]; then
    if [ "$outputIsError" == "true" ]; then
      echo "No match for $stringSelector found"
    fi
    return 1
  fi
  if echo $matches | xargs echo | grep " " >/dev/null; then
    if [ "$outputIsError" == "true" ]; then
      echo "Multiple matches for $stringSelector found:
$matches"
    fi
    return 1
  fi
  if [ "$outputIsError" == "false" ]; then
    echo "$matches"
  fi
  return 0
}

function chooseString() {
  selector="$1"
  choices="$2"
  outputErrorMessage="$3"
  # try contains match
  if uniqueStringMatch "${selector}" "$choices" "$outputErrorMessage"; then
    return
  fi

  # try prefix match
  if uniqueStringMatch "^${selector}" "$choices" "$outputErrorMessage"; then
    return
  fi

  # try unique match
  if uniqueStringMatch "^${selector}$" "$choices" "$outputErrorMessage"; then
    return
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
}


if [ "$command" == "new" ]; then
  newSessionName="$1"
  setSessionName "$newSessionName"
  exit
fi

if [ "$command" == "detach" -o "$command" == "det" ]; then
  newSessionName="unset"
  setSessionName "$newSessionName"
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

if [ "$command" == "attach" -o "$command" == "at" ]; then
  newSessionName="$1"
  setSessionName "$newSessionName" autocomplete
  exit
fi

if [ "$command" == "resolve" -o "$command" == "res" ]; then
  resolveSessionName="$1"
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

function relpath() {
  abspath="$1"
  realpath "$abspath" --relative-to .
}

if [ "$command" == "hist" ]; then
  requireSameDir=false
  removeDuplicates=false
  verbose=false
  includeAllSessions=false
  length=10

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
      continue;
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
    echo "In ${filename}:"
    histCommand="cat $historyFiles"
    if [ "$requireSameDir" == "true" ]; then
      histCommand="$histCommand | grep '$PWD '"
    fi
    if [ "$verbose" == "false" ]; then
      histCommand="$histCommand | sed 's/^\([^ ]*\) \([^ ]*\) //'"
    fi
    if [ "$removeDuplicates" == "true" ]; then
      uniquer="$(relpath $dirOfThisFile/impl/latest-uniq.py)"
      histCommand="$histCommand | $uniquer"
    fi
    if [ "$length" != "" ]; then
      histCommand="$histCommand | tail -n $length"
    fi
    bash -c "$histCommand"
    echo
  done
  exit
fi

if [ "$command" == "dirs" ]; then
  count="$1"
  if [ "$count" == "" ]; then
    count="10"
  fi
  historyFile="$sessionsDir/$sessionName/history"
  uniquer="$(relpath $dirOfThisFile/impl/latest-uniq.py)"

  echo "Last $count unique directories in ${sessionName}:"
  cat "$historyFile" | sed 's/ .*//' | "$uniquer" | tail -n "$count"
  exit
fi

if [ "$command" == "executing" ]; then
  historyFile="${sessionDir}/history"
  if [ ! -e "${historyFile}" ]; then
    mkdir -p "$(dirname ${historyFile})"
  fi
  echo "$PWD $(date +%Y-%m-%d:%H:%M:%S) $*" >> "${historyFile}"
  exit
fi

# didn't find a command
usage
