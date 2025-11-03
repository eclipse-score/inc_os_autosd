# AutoSD Toolchains

This directory contains Bazel toolchain definitions for building with AutoSD GCC compilers.

## Usage

### In your MODULE.bazel

```python
# Use local path during development, or git_override for published versions
local_path_override(
    module_name = "os_autosd",
    path = "/path/to/inc_os_autosd/"
)

bazel_dep(name = "os_autosd", version = "1.0.0")

# Configure AutoSD 9 GCC toolchain
autosd_9_gcc = use_extension("@os_autosd//toolchain/autosd_9_gcc:extensions.bzl", "autosd_9_gcc_extension")
autosd_9_gcc.configure(
    c_flags = ["-Wall", "-Wno-error=deprecated-declarations", "-Werror", "-fPIC"],
    cxx_flags = ["-Wall", "-Wno-error=deprecated-declarations", "-Werror", "-fPIC"],
)

use_repo(autosd_9_gcc, "autosd_9_gcc_repo")
register_toolchains("@autosd_9_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### In your .bazelrc

To disable Bazel's auto-detection of the system C++ toolchain:

```
build --incompatible_enable_cc_toolchain_resolution
build --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
```

## Available Toolchains

- **AutoSD 9 GCC**: `@os_autosd//toolchain/autosd_9_gcc`
- **AutoSD 10 GCC**: `@os_autosd//toolchain/autosd_10_gcc`

## Configuration Options

The `configure` tag accepts the following attributes:

- `c_flags`: List of C compiler flags
- `cxx_flags`: List of C++ compiler flags
- `link_flags`: List of linker flags
- `replace`: Boolean (default: false). If true, replaces default flags; if false, appends to defaults
