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
load(":manifest_auth.bzl", _render_auth = "render_auth")
load(":manifest_image.bzl", _render_image = "render_image")
load(":manifest_kernel.bzl", _render_kernel = "render_kernel")
load(":manifest_network.bzl", _render_network = "render_network")
load(
    ":manifest_partition.bzl",
    _render_content = "render_content",
    _render_qm = "render_qm",
)
load(":manifest_utils.bzl", _render_string_field = "render_string_field")

AibManifestInfo = provider(
    doc = "Additional files needed when consuming a generated AIB manifest.",
    fields = {
        "inputs": "Files referenced by the manifest.",
    },
)

def _aib_manifest_impl(ctx):
    """Implementation function for the aib_manifest rule."""

    manifest_file = ctx.actions.declare_file("{}.aib.yml".format(ctx.label.name))
    image_name = ctx.attr.image_name or ctx.label.name
    manifest = _render_string_field(0, "name", image_name)
    manifest += _render_string_field(0, "version", ctx.attr.image_version)
    manifest += _render_content(ctx, manifest_file.dirname)
    manifest += _render_qm(ctx, manifest_file.dirname)
    manifest += _render_network(ctx)
    manifest += _render_image(ctx)
    manifest += _render_auth(ctx)
    manifest += _render_kernel(ctx)

    ctx.actions.write(
        output = manifest_file,
        content = manifest,
    )

    return [
        DefaultInfo(files = depset([manifest_file])),
        AibManifestInfo(inputs = depset(ctx.files.srcs)),
    ]

aib_manifest = rule(
    implementation = _aib_manifest_impl,
    attrs = {
        "auth_groups": attr.string_list_dict(
            doc = (
                "Groups to create, keyed by group name. Values are optional " +
                "key=value strings for gid."
            ),
        ),
        "auth_root_password": attr.string(
            doc = (
                "Root encrypted password as returned by crypt(3). Use the " +
                "literal string \"null\" to render YAML null."
            ),
        ),
        "auth_root_ssh_keys": attr.string_list(
            doc = "Root SSH public keys to add to authorized_keys.",
        ),
        "auth_sshd_config_password_authentication": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to configure sshd " +
                "PasswordAuthentication."
            ),
        ),
        "auth_sshd_config_permit_root_login": attr.string(
            doc = (
                "Set to \"true\", \"false\", \"prohibit-password\", or " +
                "\"forced-commands-only\" to configure sshd PermitRootLogin."
            ),
        ),
        "auth_users": attr.string_list_dict(
            doc = (
                "Users to create, keyed by username. Values are key=value " +
                "strings for gid, uid, groups, description, home, shell, " +
                "password, key, keys, expiredate, and force_password_reset. " +
                "Repeat groups or keys entries to render arrays."
            ),
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = (
                "Source and generated files referenced with $(location) in " +
                "manifest attributes such as content_add_files and " +
                "qm_content_add_files. These files are added as inputs to " +
                "the image build action."
            ),
        ),
        "content_enable_repos": attr.string_list(
            doc = (
                "Named predefined default repos to enable for content " +
                "package installs, such as debug or devel."
            ),
        ),
        "content_repos": attr.string_list_dict(
            doc = (
                "Additional DNF repositories, keyed by repo id. Values are " +
                "key=value strings for baseurl, metalink, mirrorlist, and " +
                "optional priority."
            ),
        ),
        "content_rpms": attr.string_list(
            doc = "RPM package names to install into the image rootfs.",
        ),
        "content_add_files": attr.string_list_dict(
            doc = (
                "Files to add, keyed by destination path. Values are " +
                "key=value strings for source_path, url, text, source_glob, " +
                "preserve_path, max_files, and allow_empty."
            ),
        ),
        "content_add_symlinks": attr.string_dict(
            doc = "Symbolic links to create, keyed by link path with target values.",
        ),
        "content_chmod_files": attr.string_list_dict(
            doc = (
                "File modes to change, keyed by path. Values are key=value " +
                "strings for mode and recursive."
            ),
        ),
        "content_chown_files": attr.string_list_dict(
            doc = (
                "File owners to change, keyed by path. Values are key=value " +
                "strings for user, group, and recursive."
            ),
        ),
        "content_container_images": attr.string_list_dict(
            doc = (
                "Container images to embed, keyed by source image. Values " +
                "are key=value strings for tag, digest, name, " +
                "containers-transport, and index."
            ),
        ),
        "content_make_dirs": attr.string_list_dict(
            doc = (
                "Directories to create, keyed by path. Values are key=value " +
                "strings for mode, parents, and exist_ok."
            ),
        ),
        "content_remove_files": attr.string_list(
            doc = "Installed file paths to remove.",
        ),
        "content_sbom_doc_path": attr.string(
            doc = "Output path for the content SBOM SPDX document.",
        ),
        "content_systemd_disabled_services": attr.string_list(
            doc = "Systemd services to disable in the image rootfs.",
        ),
        "content_systemd_enabled_services": attr.string_list(
            doc = "Systemd services to enable in the image rootfs.",
        ),
        "content_systemd_masked_services": attr.string_list(
            doc = "Systemd services to mask in the image rootfs.",
        ),
        "image_boot_checks_commands": attr.string_dict(
            doc = (
                "Boot-check commands keyed by unique check name. Values are " +
                "the command lines to run."
            ),
        ),
        "image_boot_checks_systemd": attr.string_list(
            doc = "Systemd units used to verify a successful boot.",
        ),
        "image_cg_memory_min": attr.string(
            doc = (
                "Minimum memory value to set for system and user slices. " +
                "Only used if image_enable_reclaim_protection is true."
            ),
        ),
        "image_enable_oom_protection": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to configure OOM Killer " +
                "protection."
            ),
        ),
        "image_enable_reclaim_protection": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to configure reclaim " +
                "protection on system and user slices."
            ),
        ),
        "image_hostname": attr.string(
            doc = "Hostname to configure in the generated image.",
        ),
        "image_image_size": attr.string(
            doc = "Total image size, with suffix such as GB, GiB, or MiB.",
        ),
        "image_name": attr.string(
            doc = "Name of the image (defaults to rule name)",
        ),
        "image_ostree_ref": attr.string(
            doc = "Ostree ref name to use for the image.",
        ),
        "image_partitions_aboot_size": attr.string(
            doc = "Size of the aboot partition, with suffix such as MB or MiB.",
        ),
        "image_partitions_boot_size": attr.string(
            doc = "Size of the boot partition, with suffix such as MB or MiB.",
        ),
        "image_partitions_efi_size": attr.string(
            doc = "Size of the efi partition, with suffix such as MB or MiB.",
        ),
        "image_partitions_root_grow": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to configure root filesystem " +
                "growth to the physical image size."
            ),
        ),
        "image_partitions_sbl_size": attr.string(
            doc = "Size of the sbl partition, with suffix such as MB or MiB.",
        ),
        "image_partitions_ukiboot_size": attr.string(
            doc = "Size of the ukiboot partition, with suffix such as MB or MiB.",
        ),
        "image_partitions_var_external": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to place /var on an external " +
                "device. Mutually exclusive with image_partitions_var_size " +
                "and image_partitions_var_relative_size."
            ),
        ),
        "image_partitions_var_qm_external": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to place /var/qm on an " +
                "external device. Mutually exclusive with " +
                "image_partitions_var_qm_size and " +
                "image_partitions_var_qm_relative_size."
            ),
        ),
        "image_partitions_var_qm_relative_size": attr.string(
            doc = (
                "Size of /var/qm relative to total image size, for example " +
                "0.3. Mutually exclusive with image_partitions_var_qm_size " +
                "and image_partitions_var_qm_external."
            ),
        ),
        "image_partitions_var_qm_size": attr.string(
            doc = (
                "Size of /var/qm, with suffix such as GB or GiB. Mutually " +
                "exclusive with image_partitions_var_qm_relative_size and " +
                "image_partitions_var_qm_external."
            ),
        ),
        "image_partitions_var_qm_uuid": attr.string(
            doc = "UUID of the /var/qm partition.",
        ),
        "image_partitions_var_relative_size": attr.string(
            doc = (
                "Size of /var relative to total image size, for example 0.3. " +
                "Mutually exclusive with image_partitions_var_size and " +
                "image_partitions_var_external."
            ),
        ),
        "image_partitions_var_size": attr.string(
            doc = (
                "Size of /var, with suffix such as GB or GiB. Mutually " +
                "exclusive with image_partitions_var_relative_size and " +
                "image_partitions_var_external."
            ),
        ),
        "image_partitions_var_uuid": attr.string(
            doc = "UUID of the /var partition.",
        ),
        "image_partitions_vbmeta_size": attr.string(
            doc = "Size of the vbmeta partition, with suffix such as MB or MiB.",
        ),
        "image_sealed": attr.string(
            doc = (
                "Set to \"true\" or \"false\" to configure sealed image " +
                "behavior. The manifest default is true."
            ),
        ),
        "image_selinux_booleans": attr.string_dict(
            doc = (
                "SELinux policy booleans keyed by boolean name. Values must " +
                "be \"true\" or \"false\"."
            ),
        ),
        "image_selinux_mode": attr.string(
            doc = "SELinux mode to configure in the generated image.",
        ),
        "image_selinux_policy": attr.string(
            doc = "SELinux policy name to use.",
        ),
        "image_version": attr.string(
            doc = (
                "Version of the manifest, used as the OS version in the " +
                "ostree commit and exposed as IMAGE_VERSION in " +
                "/etc/build-info."
            ),
        ),
        "kernel_cmdline": attr.string_list(
            doc = "Extra kernel command-line options to add to the image.",
        ),
        "kernel_debug_logging": attr.bool(
            doc = "Whether to add more kernel debug logging.",
        ),
        "kernel_kernel_package": attr.string(
            doc = (
                "Custom kernel package name to use instead of " +
                "kernel-automotive."
            ),
        ),
        "kernel_kernel_version": attr.string(
            doc = "Custom kernel package version to use.",
        ),
        "kernel_loglevel": attr.int(
            default = -1,
            doc = (
                "Kernel log level to use. The default value, -1, omits the " +
                "manifest field."
            ),
        ),
        "kernel_remove_modules": attr.string_list(
            doc = "Kernel modules and dependencies to remove from the image.",
        ),
        "network_dynamic": attr.bool(
            doc = (
                "Use NetworkManager for dynamic network setup. Cannot be set " +
                "with network_static_* attributes."
            ),
        ),
        "network_static_dns": attr.string(
            doc = "DNS server IP address to use for static networking.",
        ),
        "network_static_gateway": attr.string(
            doc = "Default gateway IP address to use for static networking.",
        ),
        "network_static_iface": attr.string(
            doc = "Network interface name to configure for static networking.",
        ),
        "network_static_iface_early": attr.string(
            doc = "Network interface name during early boot.",
        ),
        "network_static_ip": attr.string(
            doc = "Fixed IP address to assign to the node.",
        ),
        "network_static_ip_prefixlen": attr.int(
            default = -1,
            doc = (
                "CIDR prefix length for the static IP address. The default " +
                "value, -1, omits the manifest field."
            ),
        ),
        "network_static_load_module": attr.string_list(
            doc = "Kernel module names to load at boot for network support.",
        ),
        "qm_container_checksum": attr.string(
            doc = "Optional container digest that is validated at boot.",
        ),
        "qm_content_add_files": attr.string_list_dict(
            doc = (
                "QM files to add, keyed by destination path. Values are " +
                "key=value strings for source_path, url, text, source_glob, " +
                "preserve_path, max_files, and allow_empty."
            ),
        ),
        "qm_content_add_symlinks": attr.string_dict(
            doc = "QM symbolic links to create, keyed by link path with target values.",
        ),
        "qm_content_chmod_files": attr.string_list_dict(
            doc = (
                "QM file modes to change, keyed by path. Values are " +
                "key=value strings for mode and recursive."
            ),
        ),
        "qm_content_chown_files": attr.string_list_dict(
            doc = (
                "QM file owners to change, keyed by path. Values are " +
                "key=value strings for user, group, and recursive."
            ),
        ),
        "qm_content_container_images": attr.string_list_dict(
            doc = (
                "QM container images to embed, keyed by source image. Values " +
                "are key=value strings for tag, digest, name, " +
                "containers-transport, and index."
            ),
        ),
        "qm_content_enable_repos": attr.string_list(
            doc = "Named predefined default repos to enable for QM content.",
        ),
        "qm_content_make_dirs": attr.string_list_dict(
            doc = (
                "QM directories to create, keyed by path. Values are " +
                "key=value strings for mode, parents, and exist_ok."
            ),
        ),
        "qm_content_remove_files": attr.string_list(
            doc = "Installed QM file paths to remove.",
        ),
        "qm_content_repos": attr.string_list_dict(
            doc = (
                "Additional QM DNF repositories, keyed by repo id. Values " +
                "are key=value strings for baseurl, metalink, mirrorlist, " +
                "and optional priority."
            ),
        ),
        "qm_content_rpms": attr.string_list(
            doc = "RPM package names to install into the QM partition.",
        ),
        "qm_content_sbom_doc_path": attr.string(
            doc = "Output path for the QM content SBOM SPDX document.",
        ),
        "qm_content_systemd_disabled_services": attr.string_list(
            doc = "Systemd services to disable in the QM partition.",
        ),
        "qm_content_systemd_enabled_services": attr.string_list(
            doc = "Systemd services to enable in the QM partition.",
        ),
        "qm_content_systemd_masked_services": attr.string_list(
            doc = "Systemd services to mask in the QM partition.",
        ),
        "qm_cpu_weight": attr.string(
            doc = "CPUWeight for the QM partition: idle or an integer from 1 to 10000.",
        ),
        "qm_memory_limit_high": attr.string(
            doc = "MemoryHigh for the QM partition.",
        ),
        "qm_memory_limit_max": attr.string(
            doc = "MemoryMax for the QM partition.",
        ),
    },
    doc = "Generates an AIB manifest from Bazel attributes.",
)
