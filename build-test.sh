#!/bin/bash

# Error on exit
set -e

# Build the kokac tool
koka -obin/kokac bin/kokac.kk
# Make it executable
chmod +x bin/kokac

# Remove old versions of the test project
rm -rf test2
# Init a test project
./bin/kokac init test2
# Change to the test project directory
pushd test2
# Make sure the test project can run
./koka -e bin/run.kk