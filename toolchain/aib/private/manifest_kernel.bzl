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
load(":manifest_utils.bzl", "render_string_field")

def render_kernel(ctx):
    kernel = ""
    if ctx.attr.kernel_debug_logging:
        kernel += "  debug_logging: true\n"
    if ctx.attr.kernel_cmdline:
        kernel += "  cmdline:\n"
        kernel += "".join(
            ["    - {}\n".format(option) for option in ctx.attr.kernel_cmdline],
        )
    if ctx.attr.kernel_kernel_package:
        kernel += render_string_field(
            2,
            "kernel_package",
            ctx.attr.kernel_kernel_package,
        )
    if ctx.attr.kernel_kernel_version:
        kernel += render_string_field(
            2,
            "kernel_version",
            ctx.attr.kernel_kernel_version,
        )
    if ctx.attr.kernel_loglevel < -1:
        fail("kernel_loglevel must be -1 to omit, or a kernel log level")
    if ctx.attr.kernel_loglevel != -1:
        kernel += render_string_field(2, "loglevel", ctx.attr.kernel_loglevel)
    if ctx.attr.kernel_remove_modules:
        kernel += "  remove_modules:\n"
        kernel += "".join(
            [
                "    - {}\n".format(module)
                for module in ctx.attr.kernel_remove_modules
            ],
        )

    if kernel:
        return "kernel:\n" + kernel
    return ""
