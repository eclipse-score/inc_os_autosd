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

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Allow override of build config (optional)
CONFIG_FLAG=""
if [ -n "${BUILD_CONFIG:-}" ]; then
    CONFIG_FLAG="--config=$BUILD_CONFIG"
    echo "Build config: $BUILD_CONFIG"
fi

# Allow override of platform (optional)
# If PLATFORM is set, it will be used with --platforms flag
PLATFORM_FLAG=""
if [ -n "${PLATFORM:-}" ]; then
    PLATFORM_FLAG="--platforms=$PLATFORM"
    echo "Platform override: $PLATFORM"
fi

# Output directory for RPMs
RPMS_DIR="${RPMS_DIR:-$REPO_ROOT/os_images/rpms}"

echo "Output directory: $RPMS_DIR"

# Build all RPM packages
echo "Building lola-demo..."
bazel build --verbose_failures --platforms=@score_bazel_platforms//:x86_64-linux-gcc_autosd-10.0-autosd //:lola-demo

echo "Building persistency-demo..."
bazel build --verbose_failures --platforms=@score_bazel_platforms//:x86_64-linux-gcc_autosd-10.0-autosd //:persistency-demo

echo "Building holden packages..."
bazel build --verbose_failures --platforms=@score_bazel_platforms//:x86_64-linux-gcc_autosd-10.0-autosd //:holden-orchestrator-demo //:holden-agent-demo

# Create output directory
mkdir -p "$RPMS_DIR"

# Copy RPMs to output directory
echo "Copying RPMs to $RPMS_DIR..."
cp bazel-out/k8-fastbuild/bin/*.rpm "$RPMS_DIR/"

# Create repository metadata
echo "Creating repository metadata..."
createrepo_c "$RPMS_DIR/"

echo "Done! RPMs available at: $RPMS_DIR"
