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

# Debug: Force fetch of toolchain and check config
echo "=== DEBUG: Fetching toolchain repository ==="
bazel fetch @score_autosd_10_toolchain//... 2>&1 || true
echo "=== DEBUG: Checking toolchain config for extra_link_flags ==="
OUTPUT_BASE=$(bazel info output_base)
echo "Output base: $OUTPUT_BASE"
TOOLCHAIN_DIR="$OUTPUT_BASE/external/score_bazel_cpp_toolchains++gcc+score_autosd_10_toolchain"
if [ -f "$TOOLCHAIN_DIR/cc_toolchain_config.bzl" ]; then
    echo "Found toolchain config, checking for extra_link_flags:"
    cat "$TOOLCHAIN_DIR/cc_toolchain_config.bzl" | grep -A5 "extra_link_flags"
else
    echo "Toolchain config not found at $TOOLCHAIN_DIR"
fi

# Build all RPM packages
echo "Building lola-demo..."
bazel build --verbose_failures --platforms=@score_bazel_platforms//:x86_64-linux-gcc_autosd-10.0-autosd //:lola-demo || true

# Debug: Check the linker params file
echo "=== DEBUG: Full linker params file content ==="
PARAMS_FILE=$(find bazel-out -name "*ipc_bridge_cpp-0.params" 2>/dev/null | head -1)
if [ -n "$PARAMS_FILE" ]; then
    echo "Params file: $PARAMS_FILE"
    cat "$PARAMS_FILE"
else
    echo "No params file found in bazel-out/, searching in output_base:"
    find "$OUTPUT_BASE" -name "*ipc_bridge_cpp-0.params" 2>/dev/null | head -3 | while read f; do
        echo "Found: $f"
        cat "$f"
    done
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
