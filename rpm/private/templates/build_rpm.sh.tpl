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

SPEC_FILE="{SPEC_FILE}"
SOURCE_BUILDROOT="$(pwd)/{BUILDROOT_PATH}"
TARBALL_PATH="$(pwd)/{TARBALL_PATH}"
RPM_OUTPUT="{RPM_OUTPUT}"
SRPM_OUTPUT="{SRPM_OUTPUT}"

echo "Building RPM and SRPM with isolated /tmp buildroot:"
echo "  Spec file: $SPEC_FILE"
echo "  Source buildroot: $SOURCE_BUILDROOT"
echo "  Source tarball: $TARBALL_PATH"
echo "  RPM output: $RPM_OUTPUT"
echo "  SRPM output: $SRPM_OUTPUT"

# Create isolated directories in /tmp
WORK_DIR=$(mktemp -d -t rpm_build_XXXXXX)
ISOLATED_BUILDROOT=$WORK_DIR/buildroot
echo "  Work directory: $WORK_DIR"
echo "  Isolated buildroot: $ISOLATED_BUILDROOT"

mkdir -p "$WORK_DIR/rpmbuild/BUILD"
mkdir -p "$WORK_DIR/rpmbuild/RPMS"
mkdir -p "$WORK_DIR/rpmbuild/SOURCES"
mkdir -p "$WORK_DIR/rpmbuild/SPECS"
mkdir -p "$WORK_DIR/rpmbuild/SRPMS"
export HOME="$WORK_DIR"

# Copy our buildroot content to isolated location
echo "Copying buildroot content to isolated location..."
mkdir -p "$ISOLATED_BUILDROOT"
if [ -d "$SOURCE_BUILDROOT" ] && [ "$(ls -A "$SOURCE_BUILDROOT" 2>/dev/null)" ]; then
    echo "Copying buildroot with symlink dereferencing..."
    cp -rL "$SOURCE_BUILDROOT"/* "$ISOLATED_BUILDROOT/"
else
    echo "Warning: Source buildroot is empty or doesn't exist"
fi

# Copy spec file and source tarball
cp "$SPEC_FILE" "$WORK_DIR/rpmbuild/SPECS/"
cp "$TARBALL_PATH" "$WORK_DIR/rpmbuild/SOURCES/"

echo "Contents of isolated buildroot:"
find "$ISOLATED_BUILDROOT" -type f -exec file {} \;

echo "Building binary RPM package..."
rpmbuild \
  --define "_topdir $WORK_DIR/rpmbuild" \
  --define "_tmppath $WORK_DIR/tmp" \
  --define "_builddir $WORK_DIR/rpmbuild/BUILD" \
  --buildroot "$ISOLATED_BUILDROOT" \
  -bb \
  "$WORK_DIR/rpmbuild/SPECS/{SPEC_BASENAME}"

echo "Building source RPM package..."
rpmbuild \
  --define "_topdir $WORK_DIR/rpmbuild" \
  --define "_tmppath $WORK_DIR/tmp" \
  -bs \
  "$WORK_DIR/rpmbuild/SPECS/{SPEC_BASENAME}"

echo "RPM build completed. Looking for generated files:"
find "$WORK_DIR/rpmbuild/RPMS" -name '*.rpm' -ls
find "$WORK_DIR/rpmbuild/SRPMS" -name '*.rpm' -ls

# Copy the resulting RPM
RPM_FOUND=$(find "$WORK_DIR/rpmbuild/RPMS" -name '*.rpm' | head -1)
if [ -n "$RPM_FOUND" ]; then
    echo "Copying $RPM_FOUND to $RPM_OUTPUT"
    cp "$RPM_FOUND" "$RPM_OUTPUT"
else
    echo "ERROR: No RPM file found!"
    exit 1
fi

# Copy the resulting SRPM
SRPM_FOUND=$(find "$WORK_DIR/rpmbuild/SRPMS" -name '*.rpm' | head -1)
if [ -n "$SRPM_FOUND" ]; then
    echo "Copying $SRPM_FOUND to $SRPM_OUTPUT"
    cp "$SRPM_FOUND" "$SRPM_OUTPUT"
else
    echo "ERROR: No SRPM file found!"
    exit 1
fi

# Cleanup
rm -rf "$WORK_DIR"

echo "Build successful:"
echo "  RPM: $RPM_OUTPUT"
echo "  SRPM: $SRPM_OUTPUT"
