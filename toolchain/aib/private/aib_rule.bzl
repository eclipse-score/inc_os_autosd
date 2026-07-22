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
load(":aib_manifest.bzl", "AibManifestInfo")

AibBuildBuilderInfo = provider(
    doc = "Information about an Automotive Image Builder builder image.",
    fields = {
        "aib": "The Automotive Image Builder executable path or command name.",
        "distro": "The OS distribution name.",
    },
)

def _target_architecture(ctx):
    if ctx.target_platform_has_constraint(
        ctx.attr._cpu_x86_64[platform_common.ConstraintValueInfo],
    ):
        return "x86_64"

    if ctx.target_platform_has_constraint(
        ctx.attr._cpu_aarch64[platform_common.ConstraintValueInfo],
    ):
        return "aarch64"

    fail("Unsupported target CPU architecture")

def _target_extension(ctx):
    if ctx.attr.target in ["abootqemu", "abootqemukvm", "qemu"]:
        return "qcow2"

    if ctx.attr.target == "azure":
        return "vhd"

    return "raw"

def _aib_build_builder_impl(ctx):
    """Implementation function for aib_build_builder rule."""

    image_name = ctx.attr.image_name or ctx.label.name
    image_file = ctx.actions.declare_file("{}.tar".format(image_name))

    build_script = ctx.actions.declare_file("{}_build.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._build_builder_template,
        output = build_script,
        substitutions = {},
        is_executable = True,
    )

    args = ctx.actions.args()
    args.add(image_file)
    args.add(ctx.attr.distro)
    args.add(ctx.attr.aib)

    # Run the build script
    ctx.actions.run(
        outputs = [image_file],
        executable = build_script,
        arguments = [args],
        mnemonic = "AibBuildBuilder",
        progress_message = "Building the builder image %s" % ctx.label.name,
        use_default_shell_env = True,
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([image_file])),
        AibBuildBuilderInfo(
            aib = ctx.attr.aib,
            distro = ctx.attr.distro,
        ),
    ]

def _aib_build_impl(ctx):
    """Implementation function for aib_build rule."""

    image_name = ctx.label.name
    image_file = ctx.actions.declare_file(
        "{}.{}.{}".format(
            image_name,
            _target_architecture(ctx),
            _target_extension(ctx),
        ),
    )
    manifest_file = ctx.file.manifest
    builder_info = ctx.attr.builder[AibBuildBuilderInfo]

    build_script = ctx.actions.declare_file("{}_build.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._build_image_template,
        output = build_script,
        substitutions = {},
        is_executable = True,
    )

    args = ctx.actions.args()
    args.add(ctx.file.builder)
    args.add(manifest_file)
    args.add(image_file)
    args.add(ctx.attr.target)
    args.add(builder_info.distro)
    args.add(builder_info.aib)

    # Run the build script
    manifest_inputs = depset()
    if AibManifestInfo in ctx.attr.manifest:
        manifest_inputs = ctx.attr.manifest[AibManifestInfo].inputs

    ctx.actions.run(
        inputs = depset(
            direct = [ctx.file.builder, manifest_file],
            transitive = [manifest_inputs],
        ),
        outputs = [image_file],
        executable = build_script,
        arguments = [args],
        mnemonic = "AibBuild",
        progress_message = "Building the image %s" % ctx.label.name,
        use_default_shell_env = True,
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [DefaultInfo(files = depset([image_file]))]

aib_build_builder = rule(
    implementation = _aib_build_builder_impl,
    attrs = {
        "aib": attr.string(
            default = "aib",
            doc = (
                "Automotive Image Builder executable path or command name. " +
                "Defaults to \"aib\" from PATH."
            ),
        ),
        "distro": attr.string(
            default = "autosd10-sig",
            doc = "OS distribution name.",
        ),
        "image_name": attr.string(
            doc = "Name of the image (defaults to rule name)",
        ),
        "_build_builder_template": attr.label(
            default = "//private/templates:build_builder.sh.tpl",
            allow_single_file = True,
        ),
    },
    doc = (
        "Produces an OCI archive containing tools that are needed to build an " +
        "AutoSD image."
    ),
)

aib_build = rule(
    implementation = _aib_build_impl,
    attrs = {
        "builder": attr.label(
            mandatory = True,
            allow_single_file = True,
            providers = [AibBuildBuilderInfo],
            doc = "AutoSD builder label",
        ),
        "manifest": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = (
                "AIB manifest file or an aib_manifest target. Files referenced " +
                "by an aib_manifest target are also added as build inputs."
            ),
        ),
        "target": attr.string(
            default = "qemu",
            doc = "The board to target, defaults to qemu.",
        ),
        "_build_image_template": attr.label(
            default = "//private/templates:build_image.sh.tpl",
            allow_single_file = True,
        ),
        "_cpu_aarch64": attr.label(
            default = "@platforms//cpu:aarch64",
        ),
        "_cpu_x86_64": attr.label(
            default = "@platforms//cpu:x86_64",
        ),
    },
    doc = "Creates an AutoSD image from an AIB manifest.",
)
