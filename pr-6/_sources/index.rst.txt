..
   # *******************************************************************************
   # Copyright (c) 2024 Contributors to the Eclipse Foundation
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

CentOS AutoSD 9 Development Target
==================================

This documentation describes the structure, usage and configuration of AutoSD in Eclipse S-CORE.

.. contents:: Table of Contents
   :depth: 2
   :local:

Overview
--------

This repsotory provides the recommended setup to build and run S-CORE in an AutoSD image.

This repository provides a standardized setup for projects using **C++** or **Rust** and **Bazel** as a build system.
It integrates best practices for build, test, CI/CD and documentation.

Requirements
------------

.. stkh_req:: CentOS AutoSD 9 Development Target
   :id: stkh_req__supported_platforms__autosd_dev
   :reqtype: Functional
   :security: NO
   :safety: QM
   :rationale: CentOS AutoSD 9 is required as a development target.
   :status: valid

Project Layout
--------------

+---------------------------------------------+------------------------------------------------------------+
| File/Folder                                 | Description                                                |
+=============================================+============================================================+
| ``README.md``                               | Repository short description and instructions              |
+---------------------------------------------+------------------------------------------------------------+
| ``toolchain/``                              | Bazel toolchain to build modules using AutoSD's tooling    |
+---------------------------------------------+------------------------------------------------------------+
| ``reference_integration/``                  | Tooling to run AutoSD in different targets, such as QEMU   |
+---------------------------------------------+------------------------------------------------------------+
| ``docs/``                                   | Documentation                                              |
+---------------------------------------------+------------------------------------------------------------+
| ``.github/workflows/``                      | CI/CD pipelines                                            |
+---------------------------------------------+------------------------------------------------------------+
| ``.vscode/``                                | Recommended VS Code settings                               |
+---------------------------------------------+------------------------------------------------------------+
| ``.bazelrc``, ``MODULE.bazel``, ``BUILD``   | Bazel configuration & settings                             |
+---------------------------------------------+------------------------------------------------------------+
| ``project_config.bzl``                      | Project-specific metadata for Bazel macros                 |
+---------------------------------------------+------------------------------------------------------------+
| ``LICENSE``                                 | Licensing information                                      |
+---------------------------------------------+------------------------------------------------------------+
| ``CONTRIBUTION.md``                         | Contribution guidelines                                    |
+---------------------------------------------+------------------------------------------------------------+

Quick Start
-----------

Documentation
~~~~~~~~~~~~~

Documentation is dealt as a top level "folder" and bazel should be used to build it by running:

.. code-block:: shell

   bazel run //:docs 


You can then proceed to open ``_build/index.html`` in a web browser.

In case you want to run a clean build from scratch, run the following command before triggering a new build:


.. code-block:: shell

   bazel clean --expunge && \
   rm -rf .cache/ && \
   rm MODULE.bazel.lock && \
    rm -rf _build

Toolchain
~~~~~~~~~

TBD


Reference Integration
~~~~~~~~~~~~~~~~~~~~~

TBD

Configuration
-------------

The `project_config.bzl` file defines metadata used by Bazel macros.

Example:

.. code-block:: python

   PROJECT_CONFIG = {
       "asil_level": "QM"
   }
