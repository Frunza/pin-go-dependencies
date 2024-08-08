#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

(cd cmd/app && go build)

# Move the generated app to the output directory
mv cmd/app/app output/app1
