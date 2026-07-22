#!/bin/bash
# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
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
set -e

export STORAGE_DIR=$(mktemp -d "$PWD/.container-storage-XXX")
export TMPDIR=$(mktemp -d "$PWD/.tmp-XXX")
export AIB_TMPDIR_BASE=$TMPDIR

mkdir -p "$TMPDIR" "$STORAGE_DIR"
cleanup() {
    rm -rf "$TMPDIR"
    podman unshare rm -rf "$STORAGE_DIR"
}
trap cleanup EXIT

IMAGE_ID=$(podman --root "$STORAGE_DIR" load -i "$1" | tail -1 | cut -d ' ' -f 3-3)
podman --root "$STORAGE_DIR" images
podman --root "$STORAGE_DIR" tag "$IMAGE_ID" "localhost/aib-build:$5"
"$6" build \
    --user-container --container-storage "$STORAGE_DIR" --distro "$5" \
    --target "$4" "$2" - "$3"
