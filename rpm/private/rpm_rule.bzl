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
"""Implementation of rpm_package rule."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _rpm_package_impl(ctx):
    """Implementation function for rpm_package rule."""

    # Declare output files
    package_name = ctx.attr.package_name or ctx.label.name
    rpm_filename = "{}-{}-{}.{}.rpm".format(
        package_name,
        ctx.attr.version,
        ctx.attr.release,
        ctx.attr.architecture,
    )
    srpm_filename = "{}-{}-{}.src.rpm".format(
        package_name,
        ctx.attr.version,
        ctx.attr.release,
    )
    tarball_filename = "{}-{}.tar.gz".format(
        package_name,
        ctx.attr.version,
    )

    rpm_file = ctx.actions.declare_file(rpm_filename)
    srpm_file = ctx.actions.declare_file(srpm_filename)
    tarball = ctx.actions.declare_file(tarball_filename)
    tarball_sha256 = ctx.actions.declare_file("{}.sha256".format(tarball_filename))
    spec_file = ctx.actions.declare_file("{}.spec".format(ctx.label.name))
    buildroot = ctx.actions.declare_directory("{}_buildroot".format(ctx.label.name))

    # Stage files in buildroot and create tarball
    _stage_files(ctx, buildroot, tarball, tarball_sha256)

    # Generate spec file with tarball checksum
    _generate_spec_file(ctx, spec_file, tarball_filename, tarball_sha256)

    # Build RPM and SRPM
    _build_rpm(ctx, spec_file, buildroot, tarball, rpm_file, srpm_file)

    return [DefaultInfo(files = depset([rpm_file, srpm_file, tarball, tarball_sha256]))]

def _generate_spec_file(ctx, spec_file, tarball_filename, tarball_sha256):
    """Generate RPM spec file with source tarball checksum."""

    # Generate requires section
    requires_section = ""
    if ctx.attr.requires:
        requires_section = "\n".join(["Requires: {}".format(req) for req in ctx.attr.requires])

    # Generate optional metadata sections
    vendor_line = "Vendor: {}".format(ctx.attr.vendor) if ctx.attr.vendor else ""
    url_line = "URL: {}".format(ctx.attr.url) if ctx.attr.url else ""

    # Basic spec file template with checksum placeholder
    spec_template = """Name: {name}
Version: {version}
Release: {release}
Summary: {summary}
License: {license}
Group: {group}
{vendor}
Packager: {packager}
{url}
Source0: {source}
# SHA256 checksum: SHA256SUM_PLACEHOLDER
BuildArch: {arch}
{requires}

# Disable debuginfo package generation since we're packaging pre-built binaries
%global debug_package %{{nil}}

%description
{description}

%prep
# Extract source tarball
%setup -c -n %{{name}}-%{{version}}

%install
# Install files from extracted tarball to buildroot
rm -rf %{{buildroot}}
mkdir -p %{{buildroot}}
cp -a * %{{buildroot}}/

%files
%defattr(644,-,-,755)
{files_list}

%changelog
* Mon Jan 01 2024 {packager} - {version}-{release}
- Initial package
""".format(
        name = ctx.attr.package_name or ctx.label.name,
        version = ctx.attr.version,
        release = ctx.attr.release,
        summary = ctx.attr.summary or "Package built with Bazel",
        license = ctx.attr.license,
        group = ctx.attr.group,
        vendor = vendor_line,
        packager = ctx.attr.packager,
        url = url_line,
        source = tarball_filename,
        arch = ctx.attr.architecture,
        requires = requires_section,
        description = ctx.attr.description or "Package built with Bazel rules_rpm",
        files_list = _generate_files_list(ctx),
    )

    # Write template to temporary file
    spec_template_file = ctx.actions.declare_file("{}.spec.template".format(ctx.label.name))
    ctx.actions.write(
        output = spec_template_file,
        content = spec_template,
    )

    # Generate spec file with checksum using a script
    inject_script = ctx.actions.declare_file("{}_inject_checksum.sh".format(ctx.label.name))
    ctx.actions.write(
        output = inject_script,
        content = """#!/bin/bash
set -e
CHECKSUM=$(cat "$1" | awk '{print $1}')
sed "s/SHA256SUM_PLACEHOLDER/$CHECKSUM/" "$2" > "$3"
""",
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [tarball_sha256, spec_template_file],
        outputs = [spec_file],
        executable = inject_script,
        arguments = [tarball_sha256.path, spec_template_file.path, spec_file.path],
        mnemonic = "GenerateSpecFile",
        progress_message = "Generating spec file with checksum for %s" % ctx.label.name,
    )

def _collect_transitive_headers(ctx):
    """Collect headers from cc_library targets based on inclusion policy."""
    if not ctx.attr.include_transitive_headers:
        return []

    transitive_headers = []

    for lib_target in ctx.attr.libraries:
        if CcInfo in lib_target:
            cc_info = lib_target[CcInfo]

            # Get all headers from transitive dependencies
            all_headers = cc_info.compilation_context.headers.to_list()
            transitive_headers.extend(all_headers)

    return transitive_headers

def _collect_direct_headers(ctx):
    """Collect only direct headers from cc_library targets."""
    direct_headers = []
    seen_basenames = {}
    for lib_target in ctx.attr.libraries:
        if CcInfo in lib_target:
            cc_info = lib_target[CcInfo]

            # Get only direct headers (not transitive)
            for header in cc_info.compilation_context.direct_headers:
                if header.basename not in seen_basenames:
                    seen_basenames[header.basename] = True
                    direct_headers.append(header)
    return direct_headers

def _collect_cc_headers(ctx):
    """Collect all headers: explicit headers + cc_library headers."""
    all_headers = list(ctx.files.headers)
    if ctx.attr.include_transitive_headers:
        cc_headers = _collect_transitive_headers(ctx)
    else:
        cc_headers = _collect_direct_headers(ctx)
    all_headers.extend(cc_headers)
    return all_headers

def _generate_files_list(ctx):
    """Generate %files section for spec file."""
    files = []

    # Add binaries with executable permissions
    for binary in ctx.files.binaries:
        files.append("%attr(755,-,-) {}/{}".format(ctx.attr.binary_dir, binary.basename))

    # Add libraries with appropriate permissions
    for library in ctx.files.libraries:
        if library.basename.endswith(".so"):
            # Shared libraries need executable permissions
            files.append("%attr(755,-,-) {}/{}".format(ctx.attr.library_dir, library.basename))
        else:
            # Static libraries keep default permissions
            files.append("{}/{}".format(ctx.attr.library_dir, library.basename))

    # Add all headers (keep default permissions)
    all_headers = _collect_cc_headers(ctx)
    for header in all_headers:
        files.append("{}/{}".format(ctx.attr.header_dir, header.basename))

    # Add configs (mark as configuration files with noreplace)
    for config in ctx.files.configs:
        files.append("%config(noreplace) {}/{}".format(ctx.attr.config_dir, config.basename))

    # Add data files (keep default permissions)
    for data_file in ctx.files.data:
        files.append("{}/{}".format(ctx.attr.data_dir, data_file.basename))

    return "\n".join(files)

def _generate_file_copy_scripts(ctx):
    """Generate a single consolidated script that handles all file copying."""

    # Collect all headers (explicit + from cc_library targets)
    all_headers = _collect_cc_headers(ctx)

    # Helper function to generate copy commands for a file type
    def _generate_copy_section(files, target_dir, file_type):
        if not files:
            return "# No {file_type}s to stage".format(file_type = file_type)

        commands = []
        commands.append("# Stage {file_type} files to {target_dir}".format(file_type = file_type, target_dir = target_dir))
        commands.append("echo \"Staging {file_type}s to {target_dir}\"".format(file_type = file_type, target_dir = target_dir))
        commands.append("mkdir -p \"$TEMP_STAGE{target_dir}\"".format(target_dir = target_dir))

        for file in files:
            commands.append("""echo "Staging {file_type}: {source_path} -> $TEMP_STAGE{target_dir}/{basename}"
if [ -L "{source_path}" ]; then
    REAL_FILE=$(readlink -f "{source_path}")
    echo "Dereferencing symlink: $REAL_FILE"
    cp "$REAL_FILE" "$TEMP_STAGE{target_dir}/{basename}"
else
    cp "{source_path}" "$TEMP_STAGE{target_dir}/{basename}"
fi""".format(
                file_type = file_type,
                source_path = file.path,
                target_dir = target_dir,
                basename = file.basename,
            ))

        return "\n".join(commands)

    # Generate all copy sections
    copy_sections = []
    copy_sections.append(_generate_copy_section(ctx.files.binaries, ctx.attr.binary_dir, "binary"))
    copy_sections.append(_generate_copy_section(ctx.files.libraries, ctx.attr.library_dir, "library"))
    copy_sections.append(_generate_copy_section(all_headers, ctx.attr.header_dir, "header"))
    copy_sections.append(_generate_copy_section(ctx.files.configs, ctx.attr.config_dir, "config"))
    copy_sections.append(_generate_copy_section(ctx.files.data, ctx.attr.data_dir, "data"))

    # Return script content directly
    return {
        "script_content": "\n\n".join(copy_sections),
    }

def _stage_files(ctx, buildroot, tarball, tarball_sha256):
    """Stage files in buildroot directory and create source tarball with checksum."""

    # Declare staging script (will be cleaned up)
    staging_script = ctx.actions.declare_file("{}_stage.sh".format(ctx.label.name))

    # Generate single consolidated copy script content
    copy_scripts = _generate_file_copy_scripts(ctx)

    # Generate main staging script using the consolidated copy script
    ctx.actions.expand_template(
        template = ctx.file._stage_files_template,
        output = staging_script,
        substitutions = {
            "{STAGE_DATA}": copy_scripts["script_content"],
            "{TARBALL_OUTPUT}": tarball.path,
            "{SHA256_OUTPUT}": tarball_sha256.path,
        },
        is_executable = True,
    )

    # Collect all headers for inputs
    all_headers = _collect_cc_headers(ctx)

    # Run staging script to create tarball, checksum, and buildroot
    ctx.actions.run(
        inputs = ctx.files.binaries + ctx.files.libraries + all_headers + ctx.files.configs + ctx.files.data,
        outputs = [buildroot, tarball, tarball_sha256],
        executable = staging_script,
        arguments = [buildroot.path],
        mnemonic = "RpmStageFiles",
        progress_message = "Staging files for RPM %s" % ctx.label.name,
    )

def _build_rpm(ctx, spec_file, buildroot, tarball, rpm_file, srpm_file):
    """Build the RPM and SRPM packages using isolated /tmp directory."""

    # Generate build script from template (will be cleaned up)
    build_script = ctx.actions.declare_file("{}_build.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._build_rpm_template,
        output = build_script,
        substitutions = {
            "{SPEC_FILE}": spec_file.path,
            "{BUILDROOT_PATH}": buildroot.path,
            "{TARBALL_PATH}": tarball.path,
            "{RPM_OUTPUT}": rpm_file.path,
            "{SRPM_OUTPUT}": srpm_file.path,
            "{SPEC_BASENAME}": spec_file.basename,
        },
        is_executable = True,
    )

    # Run the build script
    ctx.actions.run(
        inputs = [spec_file, buildroot, tarball],
        outputs = [rpm_file, srpm_file],
        executable = build_script,
        mnemonic = "RpmBuild",
        progress_message = "Building RPM and SRPM %s" % ctx.label.name,
    )

rpm_package = rule(
    implementation = _rpm_package_impl,
    attrs = {
        "binaries": attr.label_list(
            allow_files = True,
            doc = "Binary files to include in the package",
        ),
        "libraries": attr.label_list(
            allow_files = True,
            doc = "Library files to include in the package",
        ),
        "headers": attr.label_list(
            allow_files = True,
            doc = "Header files to include in the package",
        ),
        "configs": attr.label_list(
            allow_files = True,
            doc = "Configuration files to include in the package",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files to include in the package",
        ),
        "package_name": attr.string(
            doc = "Name of the RPM package (defaults to rule name)",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version of the package",
        ),
        "release": attr.string(
            default = "1",
            doc = "Release number of the package",
        ),
        "summary": attr.string(
            doc = "Short summary of the package",
        ),
        "description": attr.string(
            doc = "Detailed description of the package",
        ),
        "license": attr.string(
            default = "Apache-2.0",
            doc = "License of the package",
        ),
        "architecture": attr.string(
            default = "x86_64",
            doc = "Target architecture",
        ),
        "binary_dir": attr.string(
            default = "/usr/bin",
            doc = "Directory to install binaries",
        ),
        "library_dir": attr.string(
            default = "/usr/lib64",
            doc = "Directory to install libraries",
        ),
        "header_dir": attr.string(
            default = "/usr/include",
            doc = "Directory to install header files",
        ),
        "config_dir": attr.string(
            default = "/etc",
            doc = "Directory to install configuration files",
        ),
        "data_dir": attr.string(
            default = "/usr/share",
            doc = "Directory to install data files",
        ),
        "requires": attr.string_list(
            doc = "List of RPM package dependencies",
        ),
        "include_transitive_headers": attr.bool(
            default = False,
            doc = "Include transitive headers from cc_library dependencies. Set to False to include only direct headers (recommended for most use cases).",
        ),
        "group": attr.string(
            default = "Applications/System",
            doc = "RPM package group/category",
        ),
        "vendor": attr.string(
            default = "",
            doc = "Package vendor/organization (optional)",
        ),
        "packager": attr.string(
            default = "Bazel <bazel@example.com>",
            doc = "Package maintainer",
        ),
        "url": attr.string(
            default = "",
            doc = "Project homepage URL (optional)",
        ),
        "_stage_files_template": attr.label(
            default = "//private/templates:stage_files.sh.tpl",
            allow_single_file = True,
        ),
        "_build_rpm_template": attr.label(
            default = "//private/templates:build_rpm.sh.tpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["//toolchain:rpm_toolchain_type"],
    doc = "Creates an RPM package from Bazel targets",
)
