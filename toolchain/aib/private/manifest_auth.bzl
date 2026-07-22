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
    "parse_key_value",
    "render_bool_field",
    "render_list_field",
    "render_nullable_string_field",
    "render_string_field",
    "split_csv",
    "validate_integer_field",
)

def _render_auth_user(name, fields):
    attr_name = "auth_users[{}]".format(name)
    scalars = {}
    groups = []
    keys = []
    force_password_reset = ""

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key in ["gid", "uid", "description", "home", "shell", "password", "key", "expiredate"]:
            if key in scalars:
                fail("duplicate {} field '{}'".format(attr_name, key))
            if key in ["gid", "uid", "expiredate"]:
                validate_integer_field(attr_name, key, value)
            scalars[key] = value
        elif key == "groups":
            groups += split_csv(value)
        elif key == "keys":
            keys.append(value)
        elif key == "force_password_reset":
            if force_password_reset:
                fail("duplicate {} field 'force_password_reset'".format(attr_name))
            force_password_reset = value
        else:
            fail(
                (
                    "unsupported {} field '{}'; expected gid, uid, groups, " +
                    "description, home, shell, password, key, keys, " +
                    "expiredate, or force_password_reset"
                ).format(attr_name, key),
            )

    rendered = ""
    for key in ["gid", "uid"]:
        if key in scalars:
            rendered += render_string_field(6, key, scalars[key])
    rendered += render_list_field(6, "groups", groups)
    for key in ["description", "home", "shell", "password", "key"]:
        if key in scalars:
            rendered += render_string_field(6, key, scalars[key])
    rendered += render_list_field(6, "keys", keys)
    if "expiredate" in scalars:
        rendered += render_string_field(6, "expiredate", scalars["expiredate"])
    rendered += render_bool_field(
        6,
        attr_name + ".force_password_reset",
        "force_password_reset",
        force_password_reset,
    )

    if not rendered:
        return "    {}: {}\n".format(name, "{}")
    return "    {}:\n{}".format(name, rendered)

def _render_auth_group(name, fields):
    attr_name = "auth_groups[{}]".format(name)
    gid = ""

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key != "gid":
            fail("unsupported {} field '{}'; expected gid".format(attr_name, key))
        if gid:
            fail("duplicate {} field 'gid'".format(attr_name))
        validate_integer_field(attr_name, key, value)
        gid = value

    if not gid:
        return "    {}: {}\n".format(name, "{}")
    return "    {}:\n{}".format(name, render_string_field(6, "gid", gid))

def _render_auth_sshd_config(ctx):
    sshd_config = ""
    sshd_config += render_bool_field(
        4,
        "auth_sshd_config_password_authentication",
        "PasswordAuthentication",
        ctx.attr.auth_sshd_config_password_authentication,
    )

    permit_root_login = ctx.attr.auth_sshd_config_permit_root_login
    if permit_root_login:
        if permit_root_login in ["true", "True", "false", "False"]:
            sshd_config += render_bool_field(
                4,
                "auth_sshd_config_permit_root_login",
                "PermitRootLogin",
                permit_root_login,
            )
        elif permit_root_login in ["prohibit-password", "forced-commands-only"]:
            sshd_config += render_string_field(
                4,
                "PermitRootLogin",
                permit_root_login,
            )
        else:
            fail(
                (
                    "auth_sshd_config_permit_root_login must be true, false, " +
                    "prohibit-password, or forced-commands-only"
                ),
            )

    if not sshd_config:
        return ""
    return "  sshd_config:\n" + sshd_config

def render_auth(ctx):
    auth = ""
    auth += render_nullable_string_field(
        2,
        "root_password",
        ctx.attr.auth_root_password,
    )
    auth += render_list_field(2, "root_ssh_keys", ctx.attr.auth_root_ssh_keys)
    auth += _render_auth_sshd_config(ctx)

    if ctx.attr.auth_users:
        auth += "  users:\n"
        auth += "".join(
            [
                _render_auth_user(name, ctx.attr.auth_users[name])
                for name in sorted(ctx.attr.auth_users.keys())
            ],
        )

    if ctx.attr.auth_groups:
        auth += "  groups:\n"
        auth += "".join(
            [
                _render_auth_group(name, ctx.attr.auth_groups[name])
                for name in sorted(ctx.attr.auth_groups.keys())
            ],
        )

    if not auth:
        return ""
    return "auth:\n" + auth
