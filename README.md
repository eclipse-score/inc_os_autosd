# AutoSD Incubation Repository

This repository contains files to on-board AutoSD as a development target platform in Eclipse S-CORE.

## Project Structure

| File/Folder                         | Description                                             |
| ----------------------------------- | ------------------------------------------------------- |
| `README.md`                         | Repository short description and instructions           |
| `toolchain/`                        | Bazel toolchain to build modules using AutoSD's tooling |
| `reference_integration/`            | Tooling to run AutoSD in different targets, such a QEMU |
| `docs/`                             | Documentation                                           |
| `.github/workflows/`                | CI/CD pipelines                                         |
| `.vscode/`                          | Recommended VS Code settings                            |
| `.bazelrc`, `MODULE.bazel`, `BUILD` | Bazel configuration & settings                          |
| `project_config.bzl`                | Project-specific metadata for Bazel macros              |
| `LICENSE`                           | Licensing information                                   |
| `CONTRIBUTION.md`                   | Contribution guidelines                                 |


## Getting Started

Clone the repository by running:

```sh
git clone https://github.com/eclipse-score/inc_os_autosd.git
cd inc_os_autosd
```

A `Containerfile` is provided for convenience to run Bazel commands, build it by running:

NOTE: commands work with `docker` as well.

```
podman build -t localhost/bazer:8.3.0 .
``` 

You can then start the container by running:

```
podman run \
-it \
--rm \
--name bazel \
--userns keep-id \
--workdir /workspace \
--volume $PWD:/workspace:Z \
--tmpfs /build \
localhost/bazel:8.3.0 \
/bin/bash
```

This will start a container mounting the current directory in `/workspace` and a tmpfs volume in `/build`
that can be used for build caching.

### Documentation

Documentation is dealt as a top level "folder" and bazel should be used to build it by running:

```
bazel run //:docs 
```

You can then proceed to open `_build/index.html` in a web browser.

In case you want to run a clean build from scratch, run the following command before triggering a new build:

```
bazel clean --expunge && \
rm -rf .cache/ && \
rm MODULE.bazel.lock && \
rm -rf _build
```

### Toolchain

Intructions to use files from the [toolchain](./toolchain) folder (TBD).

### Reference Integration

Intructions to use files from the [reference_integration](./reference_integration) folder (TBD).

## License

[Apache-2.0](./LICENSE)
