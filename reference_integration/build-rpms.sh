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

# Debug: Check if extra_link_flags are in the toolchain config
echo "=== DEBUG: Checking toolchain config for extra_link_flags ==="
bazel info output_base
cat $(bazel info output_base)/external/score_bazel_cpp_toolchains++gcc+score_autosd_10_toolchain/cc_toolchain_config.bzl | grep -A5 "extra_link_flags" || echo "No extra_link_flags found in config"

# Build all RPM packages
echo "Building lola-demo..."
bazel build --verbose_failures --platforms=@score_bazel_platforms//:x86_64-linux-gcc_autosd-10.0-autosd //:lola-demo || true

# Debug: Check the linker params file
echo "=== DEBUG: Full linker params file content ==="
PARAMS_FILE=$(find $(bazel info output_base)/../../../bazel-out -name "*ipc_bridge_cpp-0.params" 2>/dev/null | head -1)
if [ -n "$PARAMS_FILE" ]; then
    echo "Params file: $PARAMS_FILE"
    cat "$PARAMS_FILE"
else
    echo "No params file found"
fi

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
