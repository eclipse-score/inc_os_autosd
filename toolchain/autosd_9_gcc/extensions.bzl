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
load(
    "//toolchain/common:toolchain_utils.bzl",
    "detect_gcc_version",
    "get_target_architecture",
    "validate_system_requirements",
)

_AUTOSD_RELEASE = "9"
_REPO_BASE_URL = "https://autosd.sig.centos.org/AutoSD-9/nightly/repos/AutoSD/compose/AutoSD"

# Packages to download (versions discovered dynamically)
_PACKAGES = [
    "gcc",
    "gcc-c++",
    "cpp",
    "binutils",
    "glibc-devel",
    "glibc-headers",
    "libstdc++-devel",
    "libstdc++",
    "kernel-headers",
    "glibc",
    "libgcc",
    "libmpc",
    "gmp",
    "mpfr",
]

def _autosd_9_gcc_toolchain_impl(repository_ctx):
    """Downloads AutoSD 9 RPM packages and creates an isolated GCC toolchain."""

    validate_system_requirements(repository_ctx)

    rpm_arch = get_target_architecture(repository_ctx)
    repo_url = "{}/{}".format(_REPO_BASE_URL, rpm_arch)

    print("Setting up AutoSD {} GCC toolchain for {}".format(_AUTOSD_RELEASE, rpm_arch))

    # Copy setup script to repository
    repository_ctx.template(
        "setup_toolchain.sh",
        Label("//toolchain/common:setup_toolchain.sh"),
        substitutions = {},
        executable = True,
    )

    # Run setup script with unbuffered output
    setup_args = ["bash", "-c", "exec ./setup_toolchain.sh 'autosd9' '{}' '{}' {}".format(
        "{}/os".format(repo_url),
        rpm_arch,
        " ".join(["'{}'".format(p) for p in _PACKAGES]),
    )]

    result = repository_ctx.execute(setup_args, quiet = False)
    if result.return_code != 0:
        fail("Failed to setup toolchain: {}\n{}".format(result.stderr, result.stdout))

    # Detect GCC version
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use flags passed from the extension (or defaults if none provided)
    autosd_flags = {
        "c_flags": getattr(repository_ctx.attr, "c_flags", []),
        "cxx_flags": getattr(repository_ctx.attr, "cxx_flags", []),
        "link_flags": getattr(repository_ctx.attr, "link_flags", []),
    }

    # Format flag lists for template substitution
    c_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("c_flags", [])])
    cxx_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("cxx_flags", [])])
    link_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("link_flags", [])])

    repository_ctx.template(
        "BUILD.bazel",
        Label("//toolchain/common:BUILD.bazel.template"),
        substitutions = {
            "{GCC_VERSION}": gcc_version,
            "{GCC_MAJOR}": gcc_major,
            "{TARGET_ARCH}": rpm_arch,
            "{C_FLAGS}": c_flags_str,
            "{CXX_FLAGS}": cxx_flags_str,
            "{LINK_FLAGS}": link_flags_str,
            "{GLIBC_CONSTRAINT}": "glibc_2_34_plus",
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("//toolchain/common:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": repository_ctx.name,
            "{DISTRO_NAME}": "autosd_9",
        },
    )

# Define the repository rule
autosd_9_gcc_toolchain = repository_rule(
    implementation = _autosd_9_gcc_toolchain_impl,
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the toolchain",
            default = ["-Wl,-z,relro", "-Wl,-z,now"],
        ),
    },
    doc = "Repository rule for AutoSD 9 GCC toolchain",
)

def _autosd_9_gcc_extension_impl(module_ctx):
    """Extension implementation for AutoSD 9 GCC toolchain"""

    # Default flags from the repository rule
    default_c_flags = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"]
    default_cxx_flags = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"]
    default_link_flags = ["-Wl,-z,relro", "-Wl,-z,now"]

    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "autosd_9_gcc_repo" if i == 0 else "autosd_9_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []
        replace_mode = False

        for config_tag in mod.tags.configure:
            if config_tag.replace:
                replace_mode = True
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        # If not in replace mode, prepend defaults
        if not replace_mode:
            c_flags = default_c_flags + c_flags
            cxx_flags = default_cxx_flags + cxx_flags
            link_flags = default_link_flags + link_flags
        else:  # If in replace mode but no flags provided, use defaults
            if not c_flags:
                c_flags = default_c_flags
            if not cxx_flags:
                cxx_flags = default_cxx_flags
            if not link_flags:
                link_flags = default_link_flags

        autosd_9_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the AutoSD 9 GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the AutoSD 9 GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the AutoSD 9 GCC toolchain",
        ),
        "replace": attr.bool(
            doc = "If True, replace default flags. If False (default), append to default flags.",
            default = False,
        ),
    },
    doc = "Configure compiler and linker flags for the AutoSD 9 GCC toolchain",
)

autosd_9_gcc_extension = module_extension(
    implementation = _autosd_9_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for AutoSD 9 GCC toolchain",
)
