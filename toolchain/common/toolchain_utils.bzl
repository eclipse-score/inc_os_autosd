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

def validate_system_requirements(repository_ctx):
    """Validate that required system tools are available.

    Args:
        repository_ctx: The repository context provided by Bazel
    """

    # Early validation of required system tools
    for tool in ["rpm2cpio", "cpio", "bash", "grep", "sed", "find", "curl"]:
        result = repository_ctx.execute(["which", tool])
        if result.return_code != 0:
            fail("Required tool '{}' is not available in PATH. Please install it before using this toolchain.".format(tool))

    # Validate rpm2cpio specifically work
    rpm2cpio_test = repository_ctx.execute(["rpm2cpio", "--help"])
    if rpm2cpio_test.return_code != 0:
        # Some versions don't support --help, try with no args (should show usage and exit with code 1)
        rpm2cpio_test2 = repository_ctx.execute(["rpm2cpio"])
        if rpm2cpio_test2.return_code not in [0, 1, 2]:
            fail("rpm2cpio tool is not working properly. Please ensure rpm2cpio is installed and functional.")

def get_target_architecture(repository_ctx):
    """Get the target architecture, mapping Bazel arch names to RPM arch names.

    Args:
        repository_ctx: The repository context provided by Bazel

    Returns:
        String: The RPM architecture name (x86_64 or aarch64)
    """

    # Map Bazel architecture to RPM architecture
    arch_mapping = {
        "amd64": "x86_64",
        "x86_64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }

    bazel_arch = repository_ctx.os.arch
    rpm_arch = arch_mapping.get(bazel_arch, bazel_arch)

    if rpm_arch not in ["x86_64", "aarch64"]:
        fail("Unsupported architecture: {}. Only x86_64 and aarch64 are supported.".format(rpm_arch))

    return rpm_arch

def detect_gcc_version(repository_ctx, gcc_path = "./usr/bin/gcc"):
    """Detect GCC version from a GCC binary.

    Args:
        repository_ctx: The repository context provided by Bazel
        gcc_path: Path to the GCC binary (defaults to extracted RPM path)

    Returns:
        Tuple: (gcc_version, gcc_major) where gcc_version is full version and gcc_major is major version
    """

    # Detect GCC version from the specified GCC binary
    gcc_version_result = repository_ctx.execute([
        "bash",
        "-c",
        "{} --version | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' | head -1".format(gcc_path),
    ])

    if gcc_version_result.return_code == 0 and gcc_version_result.stdout.strip():
        gcc_version = gcc_version_result.stdout.strip()

        # Remove any extra whitespace or newlines
        gcc_version = gcc_version.replace("\n", "").replace("\r", "").strip()
        if not gcc_version:
            fail("Failed to detect GCC version: empty version string")
    else:
        context = "host system" if gcc_path == "gcc" else "extracted toolchain"
        fail("Failed to detect GCC version from {}. Command failed with: {}".format(
            context,
            gcc_version_result.stderr if gcc_version_result.stderr else "No error output",
        ))

    gcc_major = gcc_version.split(".")[0]
    context_msg = "host" if gcc_path == "gcc" else "extracted"
    print("Detected {} GCC version: {}".format(context_msg, gcc_version))

    return gcc_version, gcc_major
