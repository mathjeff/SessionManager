#!/bin/bash
set -e

# This script runs latest-uniq.py
# This script exists to help Python find the path even when the current shell is Cygwin and the current operating system is Windows

cd "$(dirname $0)"
./latest-uniq.py "$@"
