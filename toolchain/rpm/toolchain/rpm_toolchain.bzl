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
"""RPM toolchain for rules_rpm."""

RpmInfo = provider(
    doc = "Information about the RPM toolchain",
    fields = {
        "rpmbuild": "Path to rpmbuild binary",
    },
)

def _rpm_toolchain_impl(ctx):
    """Implementation of rpm_toolchain rule."""
    toolchain_info = platform_common.ToolchainInfo(
        rpm_info = RpmInfo(
            rpmbuild = ctx.file.rpmbuild,
        ),
    )
    return [toolchain_info]

rpm_toolchain = rule(
    implementation = _rpm_toolchain_impl,
    attrs = {
        "rpmbuild": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "The rpmbuild binary",
        ),
    },
    doc = "Defines an RPM toolchain",
)

def _rpm_toolchain_repo_impl(repository_ctx):
    """Repository rule to detect RPM tools."""

    # Try to find rpmbuild
    rpmbuild_path = repository_ctx.which("rpmbuild")
    if not rpmbuild_path:
        fail("rpmbuild not found. Please install rpm-build package.")

    # Create a BUILD file that exports the rpmbuild binary
    repository_ctx.file("BUILD.bazel", content = """
package(default_visibility = ["//visibility:public"])

exports_files(["rpmbuild"])
""")

    # Symlink to the actual rpmbuild binary
    repository_ctx.symlink(rpmbuild_path, "rpmbuild")

rpm_toolchain_repo = repository_rule(
    implementation = _rpm_toolchain_repo_impl,
    doc = "Repository rule to detect and configure RPM build tools",
)
