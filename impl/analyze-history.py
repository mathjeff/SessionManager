#!/usr/bin/python3

import datetime, random, statistics, sys

class LogEntry():
  def __init__(self, directory, startTime, command):
    self.directory = directory
    self.startTime = startTime
    self.command = command

def parseTime(text):
  if "T" in text:
    separator = "T"
  else:
    separator = ":" # earlier mistake
  return datetime.datetime.strptime(text, "%Y-%m-%d" + separator + "%H:%M:%S")

def parseLogEntry(text):
  firstSpaceIndex = text.find(" ")
  if firstSpaceIndex < 0:
    return None
  directory = text[:firstSpaceIndex]
  secondSpaceIndex = text.find(" ", firstSpaceIndex + 1)
  if secondSpaceIndex < 0:
    return None
  startTimeText = text[firstSpaceIndex+1:secondSpaceIndex]
  startTime = None
  try:
    startTime = parseTime(startTimeText)
  except Exception as e:
    return None
  commandText = text[secondSpaceIndex+1:]
  return LogEntry(directory, startTime, commandText)

class Execution():
  def __init__(self, preparationTime, directory, duration, command):
    self.preparationTime = preparationTime
    self.directory = directory
    self.duration = duration
    self.command = command

class TimeAnalysis():
  def __init__(self, command, numExecutions, typicalDurationSeconds):
    self.command = command
    self.numExecutions = numExecutions
    self.typicalDurationSeconds = typicalDurationSeconds

  def getOverallSeconds(self):
    return self.typicalDurationSeconds * self.numExecutions

def analyzePaths(paths):
  print("analyzing paths " + str(paths))
  executions = parseCommandDurations(paths)

  # group executions by command
  executionsByCommand = {}
  for execution in executions:
    command = execution.command
    if command not in executionsByCommand:
      executionsByCommand[command] = []
    executionsByCommand[command].append(execution)

  # convert into list of tuples
  commandExecutions = []
  for command, executions in executionsByCommand.items():
    commandExecutions.append((command, executions))

  # filter to commands having many executions
  commandExecutions = [(command, executions) for (command, executions) in commandExecutions if len(executions) >= 3]

  # skip some specific commands for which the data isn't very helpful
  commandExecutions = [(command, executions) for (command, executions) in commandExecutions if not command.startswith("ses at ") and not command.startswith("ses aat")]

  # get representative setup times and runtimes
  overallSetupTimes = []
  approximateTotalSetupTime = 0
  overallRuntimes = []
  approximateTotalRuntime = 0
  for command, executions in commandExecutions:
    setupTimes = [execution.preparationTime.total_seconds() for execution in executions]
    runtimes = [execution.duration.total_seconds() for execution in executions]
    overallSetupTime = statistics.median(setupTimes) * len(setupTimes)
    overallRuntime = statistics.median(runtimes) * len(runtimes)
    approximateTotalSetupTime += overallSetupTime
    approximateTotalRuntime += overallRuntime
    overallSetupTimes.append(TimeAnalysis(command, len(setupTimes), statistics.median(setupTimes)))
    overallRuntimes.append(TimeAnalysis(command, len(runtimes), statistics.median(runtimes)))

  slowToSetUpCommands = selectSlowCommands(overallSetupTimes)
  print("\nCommands taking substantial time to type:")
  for analysis in slowToSetUpCommands:
    total = analysis.getOverallSeconds()
    print(" total = " + str(total) + "s =\t " + str(analysis.numExecutions) + " * " + str(analysis.typicalDurationSeconds) + "s for\t " + str(analysis.command))
  print("Total time typing commands approximately " + str((int)(approximateTotalSetupTime/3060)) + "h")

  slowToRunCommands = selectSlowCommands(overallRuntimes)
  print("\nCommands taking substantial time to run:")
  for analysis in slowToRunCommands:
    total = analysis.getOverallSeconds()
    print(" total = " + str(total) + "s =\t " + str(analysis.numExecutions) + " * " + str(analysis.typicalDurationSeconds) + "s for\t " + str(analysis.command))
  print("Total time running commands approximately " + str((int)(approximateTotalRuntime/3600)) + "h")

def selectSlowCommands(analyses):
  slowCommands = []
  while len(slowCommands) < 8 and len(analyses) > 0:
    index = chooseSlowCommandIndex(analyses)
    slowCommands.append(analyses[index])
    analyses = analyses[:index] + analyses[index+1:]
  slowCommands = sorted(slowCommands, key=TimeAnalysis.getOverallSeconds)
  return slowCommands

def chooseSlowCommandIndex(analyses):
  cumulativeDurations = []
  totalSeconds = 0
  for analysis in analyses:
    totalSeconds += analysis.getOverallSeconds()
    cumulativeDurations.append(totalSeconds)
  numCommandsToChoose = min(len(analyses), 8)
  randomMoment = random.random() * totalSeconds
  for i in range(len(analyses)):
    if randomMoment <= cumulativeDurations[i]:
      return i
  return len(analyses) - 1

def parseCommandDurations(paths):
  executions = []

  for path in paths:
    with open(path) as f:
      prevEntry = None
      prevPrevEntry = None
      for line in f:
        line = line.rstrip()
        logEntry = parseLogEntry(line)
        if logEntry is not None:
          if prevEntry is not None and prevPrevEntry:
            duration = logEntry.startTime - prevEntry.startTime
            preparationTime = prevEntry.startTime - prevPrevEntry.startTime
            execution = Execution(preparationTime, prevEntry.directory, duration, prevEntry.command)
            executions.append(execution)
          prevPrevEntry = prevEntry
          prevEntry = logEntry
  return executions

def main(args):
  analyzePaths(args)

if __name__ == "__main__":
  main(sys.argv[1:])
