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
set -euo pipefail

DISTRO="$1"
REPO_URL="$2"
ARCH="$3"
shift 3
PACKAGES=("$@")

USER_AGENT="Multi-GCC-Toolchain/1.0"

echo "Setting up toolchain from: $REPO_URL" >&2
echo "Architecture: $ARCH" >&2
echo "Packages: ${PACKAGES[*]}" >&2

download_package() {
    local pkg_name="$1"
    local html_page="$2"

    local rpm_url
    local rpm_file

    if [[ "$DISTRO" == "fedora" ]]; then
        local encoded_pkg_name="${pkg_name//+/%2B}"

        # Try URL-encoded version first (for gcc-c++)
        rpm_file=$(grep -o "href=\"${encoded_pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
            sed 's/href="//;s/"$//' | sort -V | tail -1)

        # Try non-encoded version (for libstdc++)
        if [ -z "$rpm_file" ]; then
            rpm_file=$(grep -o "href=\"${pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
                sed 's/href="//;s/"$//' | sort -V | tail -1)
        fi

        # Try case-insensitive as last resort
        if [ -z "$rpm_file" ]; then
            rpm_file=$(grep -i "href=\".*${pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
                grep -o "href=\"[^\"]*\"" | sed 's/href="//;s/"$//' | \
                grep "${pkg_name}-[0-9].*\\.${ARCH}\\.rpm" | sort -V | tail -1)
        fi

        if [ -z "$rpm_file" ]; then
            echo "[$pkg_name] ERROR: Package not found" >&2
            grep -i "${pkg_name}" "$html_page" | head -5 | sed "s/^/[$pkg_name]   /" >&2
            return 1
        fi

        rpm_file="${rpm_file//%2B/+}"
        rpm_url="${REPO_URL}/Packages/${rpm_file}"
    elif [[ "$DISTRO" == autosd* ]]; then
        local encoded_pkg_name="${pkg_name//+/%2B}"

        rpm_url=$(grep -o "href=\"[^\"]*/${encoded_pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
            sed 's/href="//;s/"$//' | sort -V | tail -1)

        if [ -z "$rpm_url" ]; then
            rpm_url=$(grep -o "href=\"[^\"]*/${pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
                sed 's/href="//;s/"$//' | sort -V | tail -1)
        fi

        if [ -z "$rpm_url" ]; then
            echo "[$pkg_name] ERROR: Package not found" >&2
            grep -i "${pkg_name}" "$html_page" | head -5 | sed "s/^/[$pkg_name]   /" >&2
            return 1
        fi

        rpm_file=$(basename "$rpm_url")
        rpm_file="${rpm_file//%2B/+}"
    else
        echo "[$pkg_name] ERROR: Unknown distro: $DISTRO" >&2
        return 1
    fi

    echo "[$pkg_name] Downloading: $rpm_file" >&2

    if ! curl -L -A "$USER_AGENT" --max-time 180 --retry 2 -# -o "$rpm_file" "$rpm_url" 2>&1 | sed "s/^/[$pkg_name] /" >&2; then
        echo "[$pkg_name] ERROR: Download failed" >&2
        rm -f "$rpm_file"
        return 1
    fi

    echo "[$pkg_name] Extracting..." >&2
    local extract_output=$(mktemp)
    if ! rpm2cpio "$rpm_file" | cpio -idm 2>"$extract_output"; then
        echo "[$pkg_name] ERROR: Extraction failed" >&2
        cat "$extract_output" | head -10 | sed "s/^/[$pkg_name]   /" >&2
        rm -f "$extract_output" "$rpm_file"
        return 1
    fi
    rm -f "$extract_output" "$rpm_file"

    echo "[$pkg_name] Done" >&2
}

# Fetch package listing once
packages_dir="${REPO_URL}/Packages"
search_url="${packages_dir}/"

# Check if subdirectory structure exists (Fedora uses first letter subdirs)
if curl -L -s -f -I -A "$USER_AGENT" "${packages_dir}/g/" >/dev/null 2>&1; then
    echo "Note: Repository uses subdirectory structure" >&2
fi

echo "Fetching package list from: ${search_url}" >&2
html_page=$(mktemp)
trap "rm -f '$html_page'" EXIT

if ! curl -L -s -f -A "$USER_AGENT" --max-time 90 --retry 2 -o "$html_page" "${search_url}"; then
    echo "ERROR: Failed to fetch package listing" >&2
    exit 1
fi

html_size=$(wc -c < "$html_page" 2>/dev/null || echo "0")
echo "Downloaded ${html_size} bytes" >&2

if [ "$html_size" -eq 0 ]; then
    echo "ERROR: Empty response from server" >&2
    exit 1
fi

echo "Downloading and extracting packages..." >&2
for pkg in "${PACKAGES[@]}"; do
    echo "========================================" >&2
    if ! download_package "$pkg" "$html_page"; then
        echo "FATAL: Failed to process package: $pkg" >&2
        exit 1
    fi
done
echo "========================================" >&2

echo "Setting up sysroot at: $(pwd)" >&2
echo "Setting up toolchain library directory..." >&2
mkdir -p usr/lib64/toolchain

shopt -s nullglob
for lib_pattern in "libbfd*.so*" "libopcodes*.so*" "libctf*.so*" "libmpc.so*" "libgmp.so*" "libmpfr.so*"; do
    for lib in usr/lib64/${lib_pattern}; do
        if [ -f "$lib" ]; then
            ln -sf "../$(basename "$lib")" usr/lib64/toolchain/
        fi
    done
done
shopt -u nullglob

echo "Creating sysroot structure..." >&2
if [ -d usr/lib64 ]; then
    mkdir -p lib64
    find usr/lib64 -type f | while read -r f; do
        filename=$(basename "$f")
        if [ ! -e "lib64/$filename" ]; then
            ln -s "../$f" "lib64/$filename"
        fi
    done
fi

if [ -d usr/lib ]; then
    mkdir -p lib
    find usr/lib -type f | while read -r f; do
        filename=$(basename "$f")
        if [ ! -e "lib/$filename" ]; then
            ln -s "../$f" "lib/$filename"
        fi
    done
fi

echo "Creating binary wrappers..." >&2
for tool in gcc g++ cpp ar ld ld.bfd objcopy strip objdump as nm gcov; do
    tool_path="usr/bin/$tool"
    if [ ! -f "$tool_path" ]; then
        continue
    fi

    cat > "${tool_path}_wrapper" <<'WRAPPER_EOF'
#!/bin/sh
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
exec env LD_LIBRARY_PATH="$REPO_ROOT/usr/lib64/toolchain:$LD_LIBRARY_PATH" "$REPO_ROOT/usr/bin/TOOL_NAME_original" "$@"
WRAPPER_EOF

    sed -i "s/TOOL_NAME/$tool/g" "${tool_path}_wrapper"
    chmod +x "${tool_path}_wrapper"
    mv "$tool_path" "${tool_path}_original"
    mv "${tool_path}_wrapper" "$tool_path"
done

if [[ "$DISTRO" == autosd* ]]; then
    echo "Applying AutoSD-specific fixes..." >&2

    if [ -f usr/bin/ld.bfd ] && [ ! -e usr/bin/ld ]; then
        ln -s ld.bfd usr/bin/ld
        echo "Created ld -> ld.bfd symlink" >&2
    fi

    # Only apply linker script fixes for AutoSD 9
    if [[ "$DISTRO" == "autosd9" ]]; then
        echo "Applying AutoSD 9 linker script fixes..." >&2
        find usr/lib64 usr/lib -name '*.so' -type f 2>/dev/null | while read -r f; do
            if head -c 1024 "$f" 2>/dev/null | grep -q "GNU ld script"; then
                echo "Fixing linker script: $f" >&2
                sed -i \
                    -e 's|/usr/lib64/|=/usr/lib64/|g' \
                    -e 's|/usr/lib/|=/usr/lib/|g' \
                    -e 's| /lib64/| =/lib64/|g' \
                    -e 's|^/lib64/|=/lib64/|g' \
                    -e 's|(/lib64/|(=/lib64/|g' \
                    -e 's| /lib/| =/lib/|g' \
                    -e 's|^/lib/|=/lib/|g' \
                    -e 's|(/lib/|(=/lib/|g' \
                    "$f"
            fi
        done
    fi
fi

echo "Toolchain setup complete!" >&2
