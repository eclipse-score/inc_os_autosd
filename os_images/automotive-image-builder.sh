#!/bin/bash

usage() {
    echo "Usage:"
    echo "  auto-image-builder.sh [OPTION...] AUTOMOTIVE_IMAGE_BUILDER_ARGUMENTS"
    echo
    echo "Options:"
    echo "  -h,--help                 - Display usage"
    echo "  -n,--nopull               - Don't attempt to pull new image"
    echo "  -a,--aib DIR              - Use the automotive-image-builder from DIR instead of the one preinstalled in the container"
    echo "  -d,--dev                  - Run aib-dev instead of aib "
    echo "  -c,--container IMAGE_NAME - Container image name, defaults to $IMAGE_NAME_DEFAULT "
    echo
}

IMAGE_NAME_DEFAULT="quay.io/centos-sig-automotive/automotive-image-builder:latest"
PULL_ARG="--pull=newer"
# prefer a-i-b preinstalled in the container
AIB="aib-dev"
AIB_SUFFIX=""
IMAGE_NAME=
SHARE_AIB_DIR=
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      break
      ;;
    -a|--aib)
      if [ ! -x "$2/bin/aib" ]; then
        echo invalid aib directory, automotive-image-builder executable not found
        exit 1
      fi
      SHARE_AIB_DIR="-v $(realpath "$2"):/aib"
      shift 2 || exit 1
      AIB="/aib/bin/aib"
      ;;
    -n|--nopull)
      PULL_ARG=
      shift 1
      ;;
    -d|--dev)
      AIB_SUFFIX="-dev"
      shift 1
      ;;
    -c|--container)
      shift 1
      if [ -z "$IMAGE_NAME" ]; then
          IMAGE_NAME=$1
          shift 1 || exit 1
      fi
      ;;
    *)
      break;
      ;;
  esac
done
AIB="$AIB$AIB_SUFFIX $*"

PODMAN=$(command -v podman || command -v docker)
if [ -z "$PODMAN" ]; then
  echo Podman or Docker are needed
  exit 1
fi

if [ -n "$container" ] || [ -f /.dockerenv ]; then
  echo "This script is not to be run from within a container"
  exit 1
fi

for i in "$@"; do
    if [[ "$i" =~ ^--container ]]; then
        echo "Do not use --container* arguments of a-i-b binary with this wrapper"
        exit 1
    fi
done

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

SHARE_PODMAN_MACHINE_ROOT=
BUILDDIR=_build
# running on Mac OS X bare metal or inside podman machine
if [ "$(uname -o)" = "Darwin" ] || [ "$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)" = "Apple Virtualization Generic Platform" ]; then
  SHARE_PODMAN_MACHINE_ROOT="-v /root:/root"
  BUILDDIR=/root/aib-work
fi
AIB_LOCAL_CONTAINER_STORAGE=${AIB_LOCAL_CONTAINER_STORAGE:=$(sudo -u "${SUDO_USER:=root}" bash -c "$PODMAN system info -f json" | jq -r .store.graphRoot)}

# For SELinux to work correctly the osbuild binary needs extra privileges and files need to be on suitable filesystem
# OSBUILD_BUILDDIR with podman machine is on local non-overlayfs filesystem /root, with native podman it needs to be on host's filesystem (shared volume /host)
EXEC="cd /host; mkdir -p $BUILDDIR; cp -f /usr/bin/osbuild $BUILDDIR/osbuild; chcon system_u:object_r:install_exec_t:s0 $BUILDDIR/osbuild; export PATH=$BUILDDIR:\$PATH; export OSBUILD_BUILDDIR=$BUILDDIR; $AIB"

# shellcheck disable=SC2086
$PODMAN run -v /dev:/dev -v "$PWD":/host -v $AIB_LOCAL_CONTAINER_STORAGE:/var/lib/containers/storage $SHARE_PODMAN_MACHINE_ROOT $SHARE_AIB_DIR --rm --privileged $PULL_ARG --security-opt label=type:unconfined_t --read-only=false $AIB_PODMAN_OPTIONS ${IMAGE_NAME:-$IMAGE_NAME_DEFAULT} /bin/bash -c "$EXEC"
