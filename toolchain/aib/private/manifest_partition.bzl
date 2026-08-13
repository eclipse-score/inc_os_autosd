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
    "field_error",
    "indent",
    "is_integer_literal",
    "parse_key_value",
    "render_bool_field",
    "render_list_field",
    "render_string_field",
    "require_unique",
    "validate_integer_field",
)

def _render_repo(indent_size, id, fields, attr_name):
    repo = {
        "id": id,
    }
    for field in fields:
        parts = field.split("=", 1)
        if len(parts) != 2 or not parts[0] or not parts[1]:
            fail("{} entries must use key=value strings: {}".format(attr_name, field))

        key = parts[0]
        value = parts[1]
        if key not in ["baseurl", "metalink", "mirrorlist", "priority"]:
            fail(
                (
                    "unsupported {} field '{}'; expected baseurl, " +
                    "metalink, mirrorlist, or priority"
                ).format(attr_name, key),
            )
        if key in repo:
            fail("duplicate {} field '{}' for repo '{}'".format(attr_name, key, id))
        if key == "priority" and not is_integer_literal(value):
            fail("{} priority for repo '{}' must be an integer".format(attr_name, id))
        repo[key] = value

    if not ("baseurl" in repo or "metalink" in repo or "mirrorlist" in repo):
        fail(
            (
                "{} repo '{}' must set one of baseurl, metalink, " +
                "or mirrorlist"
            ).format(attr_name, id),
        )

    rendered = "{}- id: {}\n".format(indent(indent_size), id)
    for key in ["baseurl", "metalink", "mirrorlist", "priority"]:
        if key in repo:
            rendered += render_string_field(indent_size + 2, key, repo[key])
    return rendered

def _render_container_image(indent_size, source, fields, attr_name):
    values = {}
    index = ""

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key in ["tag", "digest", "name", "containers-transport"]:
            require_unique(values, attr_name, key)
            if (
                key == "containers-transport" and
                value not in ["docker", "containers-storage"]
            ):
                fail(
                    "{} field 'containers-transport' must be docker or "
                        .format(attr_name) +
                    "containers-storage",
                )
            values[key] = value
        elif key == "index":
            if index:
                fail("duplicate {} field 'index'".format(attr_name))
            index = value
        else:
            field_error(
                attr_name,
                key,
                "tag, digest, name, containers-transport, or index",
            )

    rendered = "{}- source: {}\n".format(indent(indent_size), source)
    for key in ["tag", "digest", "name", "containers-transport"]:
        if key in values:
            rendered += render_string_field(indent_size + 2, key, values[key])
    rendered += render_bool_field(indent_size + 2, attr_name + ".index", "index", index)
    return rendered

def _render_add_file(indent_size, path, fields, attr_name):
    values = {}
    bools = {}

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key in ["source_path", "url", "text", "source_glob", "max_files"]:
            require_unique(values, attr_name, key)
            if key == "max_files":
                validate_integer_field(attr_name, key, value)
            values[key] = value
        elif key in ["preserve_path", "allow_empty"]:
            require_unique(bools, attr_name, key)
            bools[key] = value
        else:
            field_error(
                attr_name,
                key,
                (
                    "source_path, url, text, source_glob, preserve_path, " +
                    "max_files, or allow_empty"
                ),
            )

    source_keys = 0
    for key in ["source_path", "url", "text", "source_glob"]:
        if key in values:
            source_keys += 1
    if source_keys != 1:
        fail(
            (
                "{} must set exactly one of source_path, url, text, or " +
                "source_glob"
            ).format(attr_name),
        )

    rendered = "{}- path: {}\n".format(indent(indent_size), path)
    for key in ["source_path", "url", "text", "source_glob"]:
        if key in values:
            rendered += render_string_field(indent_size + 2, key, values[key])
    for key in ["preserve_path", "allow_empty"]:
        if key in bools:
            rendered += render_bool_field(
                indent_size + 2,
                attr_name + "." + key,
                key,
                bools[key],
            )
    if "max_files" in values:
        rendered += render_string_field(
            indent_size + 2,
            "max_files",
            values["max_files"],
        )
    return rendered

def _render_chmod_file(indent_size, path, fields, attr_name):
    values = {}
    recursive = ""

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key == "mode":
            require_unique(values, attr_name, key)
            values[key] = value
        elif key == "recursive":
            if recursive:
                fail("duplicate {} field 'recursive'".format(attr_name))
            recursive = value
        else:
            field_error(attr_name, key, "mode or recursive")

    if "mode" not in values:
        fail("{} must set mode".format(attr_name))

    rendered = "{}- path: {}\n".format(indent(indent_size), path)
    rendered += render_string_field(indent_size + 2, "mode", values["mode"])
    rendered += render_bool_field(
        indent_size + 2,
        attr_name + ".recursive",
        "recursive",
        recursive,
    )
    return rendered

def _render_chown_file(indent_size, path, fields, attr_name):
    values = {}
    recursive = ""

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key in ["user", "group"]:
            require_unique(values, attr_name, key)
            values[key] = value
        elif key == "recursive":
            if recursive:
                fail("duplicate {} field 'recursive'".format(attr_name))
            recursive = value
        else:
            field_error(attr_name, key, "user, group, or recursive")

    if not ("user" in values or "group" in values):
        fail("{} must set user or group".format(attr_name))

    rendered = "{}- path: {}\n".format(indent(indent_size), path)
    for key in ["user", "group"]:
        if key in values:
            rendered += render_string_field(indent_size + 2, key, values[key])
    rendered += render_bool_field(
        indent_size + 2,
        attr_name + ".recursive",
        "recursive",
        recursive,
    )
    return rendered

def _render_make_dir(indent_size, path, fields, attr_name):
    values = {}
    bools = {}

    for field in fields:
        parts = parse_key_value(attr_name, field)
        key = parts[0]
        value = parts[1]

        if key == "mode":
            require_unique(values, attr_name, key)
            values[key] = value
        elif key in ["parents", "exist_ok"]:
            require_unique(bools, attr_name, key)
            bools[key] = value
        else:
            field_error(attr_name, key, "mode, parents, or exist_ok")

    rendered = "{}- path: {}\n".format(indent(indent_size), path)
    if "mode" in values:
        rendered += render_string_field(indent_size + 2, "mode", values["mode"])
    for key in ["parents", "exist_ok"]:
        if key in bools:
            rendered += render_bool_field(
                indent_size + 2,
                attr_name + "." + key,
                key,
                bools[key],
            )
    return rendered

def _render_keyed_object_list(indent_size, entries, attr_name, render_item):
    return "".join(
        [
            render_item(
                indent_size,
                name,
                entries[name],
                "{}[{}]".format(attr_name, name),
            )
            for name in sorted(entries.keys())
        ],
    )

def _render_symlink_list(indent_size, links):
    return "".join(
        [
            "{}- link: {}\n{}target: {}\n".format(
                indent(indent_size),
                link,
                indent(indent_size + 2),
                links[link],
            )
            for link in sorted(links.keys())
        ],
    )

def _render_remove_file_list(indent_size, paths):
    return "".join(
        [
            "{}- path: {}\n".format(indent(indent_size), path)
            for path in paths
        ],
    )

def _relative_path(path, directory):
    """Returns path relative to directory. Both paths are execroot-relative."""

    path_parts = path.split("/")
    directory_parts = directory.split("/")
    common_parts = 0
    for index in range(min(len(path_parts), len(directory_parts))):
        if path_parts[index] != directory_parts[index]:
            break
        common_parts += 1

    return "/".join(
        [".."] * (len(directory_parts) - common_parts) +
        path_parts[common_parts:],
    )

def _expand_manifest_locations(ctx, value, manifest_directory):
    """Expands locations as paths relative to the generated manifest."""

    expanded = ctx.expand_location(value, targets = ctx.attr.srcs)

    # expand_location returns paths relative to the action's execroot, while
    # AIB resolves source_path relative to the manifest. Replace longer paths
    # first so a path that is a prefix of another input cannot corrupt it.
    replacements = sorted([
        (-len(file.path), file.path, _relative_path(file.path, manifest_directory))
        for file in ctx.files.srcs
    ])
    for _, path, relative_path in replacements:
        expanded = expanded.replace(path, relative_path)

    return expanded

def _render_partition(ctx, attr_prefix, indent_size, manifest_directory):
    partition = ""
    partition += render_list_field(
        indent_size,
        "rpms",
        getattr(ctx.attr, attr_prefix + "_rpms"),
    )
    partition += render_list_field(
        indent_size,
        "enable_repos",
        getattr(ctx.attr, attr_prefix + "_enable_repos"),
    )

    repos = getattr(ctx.attr, attr_prefix + "_repos")
    if repos:
        partition += "{}repos:\n".format(indent(indent_size))
        partition += "".join(
            [
                _render_repo(
                    indent_size + 2,
                    id,
                    repos[id],
                    attr_prefix + "_repos[{}]".format(id),
                )
                for id in sorted(repos.keys())
            ],
        )

    container_images = getattr(ctx.attr, attr_prefix + "_container_images")
    if container_images:
        partition += "{}container_images:\n".format(indent(indent_size))
        partition += _render_keyed_object_list(
            indent_size + 2,
            container_images,
            attr_prefix + "_container_images",
            _render_container_image,
        )

    add_files = {
        path: [
            _expand_manifest_locations(ctx, field, manifest_directory)
            for field in fields
        ]
        for path, fields in getattr(ctx.attr, attr_prefix + "_add_files").items()
    }
    if add_files:
        partition += "{}add_files:\n".format(indent(indent_size))
        partition += _render_keyed_object_list(
            indent_size + 2,
            add_files,
            attr_prefix + "_add_files",
            _render_add_file,
        )

    chmod_files = getattr(ctx.attr, attr_prefix + "_chmod_files")
    if chmod_files:
        partition += "{}chmod_files:\n".format(indent(indent_size))
        partition += _render_keyed_object_list(
            indent_size + 2,
            chmod_files,
            attr_prefix + "_chmod_files",
            _render_chmod_file,
        )

    chown_files = getattr(ctx.attr, attr_prefix + "_chown_files")
    if chown_files:
        partition += "{}chown_files:\n".format(indent(indent_size))
        partition += _render_keyed_object_list(
            indent_size + 2,
            chown_files,
            attr_prefix + "_chown_files",
            _render_chown_file,
        )

    remove_files = getattr(ctx.attr, attr_prefix + "_remove_files")
    if remove_files:
        partition += "{}remove_files:\n".format(indent(indent_size))
        partition += _render_remove_file_list(indent_size + 2, remove_files)

    make_dirs = getattr(ctx.attr, attr_prefix + "_make_dirs")
    if make_dirs:
        partition += "{}make_dirs:\n".format(indent(indent_size))
        partition += _render_keyed_object_list(
            indent_size + 2,
            make_dirs,
            attr_prefix + "_make_dirs",
            _render_make_dir,
        )

    add_symlinks = getattr(ctx.attr, attr_prefix + "_add_symlinks")
    if add_symlinks:
        partition += "{}add_symlinks:\n".format(indent(indent_size))
        partition += _render_symlink_list(indent_size + 2, add_symlinks)

    systemd = ""
    systemd += render_list_field(
        indent_size + 2,
        "enabled_services",
        getattr(ctx.attr, attr_prefix + "_systemd_enabled_services"),
    )
    systemd += render_list_field(
        indent_size + 2,
        "disabled_services",
        getattr(ctx.attr, attr_prefix + "_systemd_disabled_services"),
    )
    systemd += render_list_field(
        indent_size + 2,
        "masked_services",
        getattr(ctx.attr, attr_prefix + "_systemd_masked_services"),
    )
    if systemd:
        partition += "{}systemd:\n".format(indent(indent_size)) + systemd

    sbom_doc_path = getattr(ctx.attr, attr_prefix + "_sbom_doc_path")
    if sbom_doc_path:
        partition += "{}sbom:\n".format(indent(indent_size))
        partition += render_string_field(indent_size + 2, "doc_path", sbom_doc_path)

    return partition

def render_content(ctx, manifest_directory):
    content = _render_partition(ctx, "content", 2, manifest_directory)

    if content:
        return "content:\n" + content
    return ""

def _validate_qm_cpu_weight(value):
    if value == "idle":
        return
    if not is_integer_literal(value):
        fail("qm_cpu_weight must be idle or an integer from 1 to 10000")

    weight = int(value)
    if weight < 1 or weight > 10000:
        fail("qm_cpu_weight must be idle or an integer from 1 to 10000")

def render_qm(ctx, manifest_directory):
    qm = ""

    content = _render_partition(ctx, "qm_content", 4, manifest_directory)
    if content:
        qm += "  content:\n" + content

    memory_limit = ""
    memory_limit += render_string_field(
        4,
        "max",
        ctx.attr.qm_memory_limit_max,
    )
    memory_limit += render_string_field(
        4,
        "high",
        ctx.attr.qm_memory_limit_high,
    )
    if memory_limit:
        qm += "  memory_limit:\n" + memory_limit

    if ctx.attr.qm_cpu_weight:
        _validate_qm_cpu_weight(ctx.attr.qm_cpu_weight)
        qm += render_string_field(2, "cpu_weight", ctx.attr.qm_cpu_weight)
    qm += render_string_field(
        2,
        "container_checksum",
        ctx.attr.qm_container_checksum,
    )

    if qm:
        return "qm:\n" + qm
    return ""
