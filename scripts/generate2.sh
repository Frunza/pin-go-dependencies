#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

# Cleanup
rm -f go.mod go.sum

# Generate the app by using go build without go.mod and go.sum
go mod init app
go mod tidy
(cd cmd/app && go build)

# Move the generated app to the output directory
mv cmd/app/app output/app2
