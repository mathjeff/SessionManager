#!/usr/bin/python3

import sys

# read all lines in order
allLines = []
for line in sys.stdin:
  allLines.append(line)

# read lines in reverse and find the first copy of each unique line
uniqueLinesList = []
uniqueLinesSet = set()
for line in reversed(allLines):
  if line not in uniqueLinesSet:
    uniqueLinesSet.add(line)
    uniqueLinesList.append(line)

# output unique lines in reverse order
uniqueLinesList = reversed(uniqueLinesList)
for line in uniqueLinesList:
  print(line, end='')
