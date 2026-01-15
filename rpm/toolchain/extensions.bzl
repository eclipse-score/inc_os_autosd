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
"""Module extensions for RPM toolchain."""

load(":rpm_toolchain.bzl", "rpm_toolchain_repo")

def _rpm_toolchain_impl(module_ctx):  # @unused
    """Implementation of rpm_toolchain module extension."""
    rpm_toolchain_repo(name = "rpm_toolchain")

rpm_toolchain = module_extension(
    implementation = _rpm_toolchain_impl,
    doc = "Extension to set up RPM toolchain",
)
