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

def render_network(ctx):
    static = ""
    static += render_string_field(4, "ip", ctx.attr.network_static_ip)
    if ctx.attr.network_static_ip_prefixlen < -1:
        fail("network_static_ip_prefixlen must be -1 to omit, or a prefix length")
    if ctx.attr.network_static_ip_prefixlen != -1:
        static += render_string_field(
            4,
            "ip_prefixlen",
            ctx.attr.network_static_ip_prefixlen,
        )
    static += render_string_field(4, "gateway", ctx.attr.network_static_gateway)
    static += render_string_field(4, "dns", ctx.attr.network_static_dns)
    static += render_string_field(4, "iface", ctx.attr.network_static_iface)
    static += render_string_field(
        4,
        "iface_early",
        ctx.attr.network_static_iface_early,
    )
    if ctx.attr.network_static_load_module:
        static += "    load_module:\n"
        static += "".join(
            [
                "      - {}\n".format(module)
                for module in ctx.attr.network_static_load_module
            ],
        )

    if ctx.attr.network_dynamic and static:
        fail("network_dynamic cannot be set with network_static_* attributes")
    if ctx.attr.network_dynamic:
        return "network:\n  dynamic: {}\n"
    if static:
        return "network:\n  static:\n" + static
    return ""
