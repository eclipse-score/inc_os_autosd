# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
#!/bin/bash
set -e
set -x

BUILDROOT=$(cd $(dirname $1) && pwd)/$(basename $1)
TARBALL_OUTPUT=$(cd $(dirname {TARBALL_OUTPUT}) && pwd)/$(basename {TARBALL_OUTPUT})
SHA256_OUTPUT=$(cd $(dirname {SHA256_OUTPUT}) && pwd)/$(basename {SHA256_OUTPUT})

echo "Target buildroot: $BUILDROOT"
echo "Source tarball: $TARBALL_OUTPUT"
echo "SHA256 output: $SHA256_OUTPUT"

# Create a temporary directory for staging
TEMP_STAGE=$(mktemp -d)
echo "Using temporary staging directory: $TEMP_STAGE"

{STAGE_DATA}

echo "Creating compressed source tarball..."
cd "$TEMP_STAGE"
tar -czf "$TARBALL_OUTPUT" .

echo "Computing SHA256 checksum..."
TARBALL_BASENAME=$(basename "$TARBALL_OUTPUT")
sha256sum "$TARBALL_OUTPUT" | sed "s|$TARBALL_OUTPUT|$TARBALL_BASENAME|" > "$SHA256_OUTPUT"
echo "SHA256: $(cat $SHA256_OUTPUT)"

echo "Extracting to buildroot..."
mkdir -p "$BUILDROOT"
cp -r * "$BUILDROOT/"

echo "Cleaning up temporary staging directory"
rm -rf "$TEMP_STAGE"

echo "Final buildroot contents:"
find "$BUILDROOT" -type f -exec file {} \;
