#!/bin/bash

# Error on exit
set -e

# Build the kokaw tool
koka -obin/kokaw bin/kokaw.kk
# Make it executable
chmod +x bin/kokaw

# Remove old versions of the test project
rm -rf test2
# Init a test project
./bin/kokaw init test2
# Change to the test project directory
pushd test2
# Make sure the test project can run
./kokaw -e bin/run.kk