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
"""Public API for rules_aib."""

load("//private:aib_manifest.bzl", _aib_manifest = "aib_manifest")
load("//private:aib_rule.bzl", _aib_build = "aib_build", _aib_build_builder = "aib_build_builder")

aib_build = _aib_build
aib_build_builder = _aib_build_builder
aib_manifest = _aib_manifest
