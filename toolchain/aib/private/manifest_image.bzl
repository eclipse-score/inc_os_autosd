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
    ":manifest_utils.bzl",
    "normalize_bool_attr",
    "render_bool_field",
    "render_string_field",
)

def _render_var_partition(ctx, name):
    prefix = "image_partitions_{}_".format(name)
    relative_size = getattr(ctx.attr, prefix + "relative_size")
    size = getattr(ctx.attr, prefix + "size")
    external = getattr(ctx.attr, prefix + "external")
    uuid = getattr(ctx.attr, prefix + "uuid")

    size_modes = 0
    if relative_size:
        size_modes += 1
    if size:
        size_modes += 1
    if external:
        size_modes += 1
    if size_modes > 1:
        fail(
            (
                "{}relative_size, {}size, and {}external are mutually " +
                "exclusive"
            ).format(prefix, prefix, prefix),
        )

    partition = ""
    partition += render_string_field(6, "relative_size", relative_size)
    partition += render_string_field(6, "size", size)
    partition += render_bool_field(6, prefix + "external", "external", external)
    partition += render_string_field(6, "uuid", uuid)

    if not partition:
        return ""
    return "    {}:\n{}".format(name, partition)

def _render_image_partitions(ctx):
    partitions = ""

    root = render_bool_field(
        6,
        "image_partitions_root_grow",
        "grow",
        ctx.attr.image_partitions_root_grow,
    )
    if root:
        partitions += "    root:\n" + root

    for name in ["aboot", "ukiboot", "boot", "efi", "vbmeta", "sbl"]:
        size = getattr(ctx.attr, "image_partitions_{}_size".format(name))
        if size:
            partitions += "    {}:\n".format(name)
            partitions += render_string_field(6, "size", size)

    partitions += _render_var_partition(ctx, "var")
    partitions += _render_var_partition(ctx, "var_qm")

    if not partitions:
        return ""
    return "  partitions:\n" + partitions

def _render_image_selinux_booleans(ctx):
    if not ctx.attr.image_selinux_booleans:
        return ""

    rendered = "  selinux_booleans:\n"
    for name in sorted(ctx.attr.image_selinux_booleans.keys()):
        rendered += "    {}: {}\n".format(
            name,
            normalize_bool_attr(
                "image_selinux_booleans[{}]".format(name),
                ctx.attr.image_selinux_booleans[name],
            ),
        )
    return rendered

def _render_image_boot_checks(ctx):
    boot_checks = ""

    if ctx.attr.image_boot_checks_commands:
        boot_checks += "    commands:\n"
        for name in sorted(ctx.attr.image_boot_checks_commands.keys()):
            boot_checks += "      - name: {}\n".format(name)
            boot_checks += render_string_field(
                8,
                "cmd",
                ctx.attr.image_boot_checks_commands[name],
            )

    if ctx.attr.image_boot_checks_systemd:
        boot_checks += "    systemd:\n"
        boot_checks += "".join(
            [
                "      - {}\n".format(unit)
                for unit in ctx.attr.image_boot_checks_systemd
            ],
        )

    if not boot_checks:
        return ""
    return "  boot_checks:\n" + boot_checks

def render_image(ctx):
    image = ""
    image += render_string_field(2, "image_size", ctx.attr.image_image_size)
    image += render_bool_field(2, "image_sealed", "sealed", ctx.attr.image_sealed)
    image += render_bool_field(
        2,
        "image_enable_oom_protection",
        "enable_oom_protection",
        ctx.attr.image_enable_oom_protection,
    )
    image += render_bool_field(
        2,
        "image_enable_reclaim_protection",
        "enable_reclaim_protection",
        ctx.attr.image_enable_reclaim_protection,
    )
    image += render_string_field(2, "cg_memory_min", ctx.attr.image_cg_memory_min)
    image += render_string_field(2, "hostname", ctx.attr.image_hostname)
    image += render_string_field(2, "selinux_mode", ctx.attr.image_selinux_mode)
    image += render_string_field(
        2,
        "selinux_policy",
        ctx.attr.image_selinux_policy,
    )
    image += _render_image_selinux_booleans(ctx)
    image += _render_image_partitions(ctx)
    image += render_string_field(2, "ostree_ref", ctx.attr.image_ostree_ref)
    image += _render_image_boot_checks(ctx)

    if image:
        return "image:\n" + image
    return ""
