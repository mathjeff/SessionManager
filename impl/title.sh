#!/bin/bash
# This script outputs stdin and adds a title if the input is nonempty
title="$1"
while read line
do
  if [ "$title" != "" ]; then
    echo "$title"
    title=""
  fi
  echo "$line"
done < /dev/stdin
