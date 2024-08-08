#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

SHA1=$(sha256sum output/app1 | awk '{print $1}')
SHA2=$(sha256sum output/app2 | awk '{print $1}')

echo "Printing the hashes of the generated apps, with and without go.mod, go.sum:"
echo $SHA1
echo $SHA2
