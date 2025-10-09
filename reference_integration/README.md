# AutoSD Refeference Integration

This folder contains files and tooling needed to build and run an AutoSD image in QEMU.

## Requirements

* linux host
* [osbuild](https://github.com/osbuild/osbuild)
* [automotive-image-builder](https://gitlab.com/CentOS/automotive/src/automotive-image-builder)
* podman/docker (optional)

## Building

Note: Add `--define-file build/vars-devel.yml` to the build command if using for local development,
which sets the root password to "password".

This folder provides two images:

* `platform-execution.aib.yml`: a base image to run bazel and build components;
* `platform-target.aib.yml`: an image to run components built in the exectuion platform (previous item).

### Bare Metal

To build a new image targeting qemu (needs sudo):

```
sudo autosd-image-builder build \
--define-file build/vars.yml \
--build-dir outputs/ \
--distro autosd9 \
--mode image \
--target qemu \
--export qcow2 \
build/image.aib.yml \
outputs/disk.qcow2
```

"Fix" the generated disk file:

```
sudo chown $(logname) outputs/disk.qcow2
```

### Container Script

A script is provided to run automotive-image-builder inside a container:

```
sudo bash ./scripts/container-build.sh build \
--define-file build/vars.yml \
--build-dir outputs/ \
--distro autosd9 \
--mode image \
--target qemu \
--export qcow2 \
build/image.aib.yml \
outputs/disk.qcow2
```

The same bare meta situation applies, "fix" the generated disk file:

```
sudo chown $(logname) outputs/disk.qcow2
```

## Running

If you installed automotive-image-builder in your local machine/host, you can use `automotive-image-runner`,
which is just a wrapper of QEMU:

``` 
automotive-image-runner --nographic outputs/disk.qcow2
```

You can also use qemu directly, by mounting `disk.qcow2` using qemu-system, sample command bellow:

```
/usr/bin/qemu-system-x86_64 \
-drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
-drive file=/usr/share/OVMF/OVMF_VARS.fd,if=pflash,format=raw,unit=1,snapshot=on,readonly=off \
-smp 20 \
-nographic \
-enable-kvm \
-m 2G \
-machine q35 \
-cpu host \
-device virtio-net-pci,netdev=n0,mac=FE:00:e2:0d:ba:4d \
-netdev user,id=n0,net=10.0.2.0/24,hostfwd=tcp::2222-:22 \
-drive file=outputs/disk.qcow2,index=0,media=disk,format=qcow2,if=virtio,id=rootdisk,snapshot=off
```
