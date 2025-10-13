lola_demo
=========

This demo build an AutoSD image using [Automotive-Image-Builder](https://gitlab.com/CentOS/automotive/src/automotive-image-builder).
This image comes pre-populated with the S-core's [communication](https://github.com/eclipse-score/communication) project packaged as RPM in a [COPR](https://copr.fedorainfracloud.org/coprs/pingou/score-playground/) repository as well as the [QM](https://github.com/containers/qm) project.

The image is pre-configured to allow the communication project to send and receive messages within the root partition but also between the root partition and the QM partition.


Some things to know about this demo:
- The RPM packaging, currently, doesn't rely on Bazel. This is something that is being fixed, but in the current stage it is not there yet.
- Baselibs and communication have had to get some patches, some of which have already been sent upstream:
  - Missing headers: https://github.com/eclipse-score/communication/pull/64
  - Missing headers: https://github.com/eclipse-score/baselibs/pull/19
  - Compilation issues on newer GCC + support for Linux ARM64: https://github.com/eclipse-score/baselibs/pull/22
  - Fix dangling references and compiler warnings for newer GCC: https://github.com/eclipse-score/communication/pull/68
  - Fix Google benchmark main function scope: https://github.com/eclipse-score/communication/pull/67
- Other changes have not yet been sent upstream:
  - Add the ability to configure the path where communication opens the shared memory segments: https://github.com/eclipse-score/communication/commit/127a64f07f48e1d69783dc20f217da813115dbe6 (not the final version of this change)

The goal of this last commit is to avoid having to mount the entire `/dev/shm` into the QM partition and instead mount just a subfolder: `/dev/shm/lola_qm`.


To run the demo:
- Build the AutoSD image using Automotive-Image-Builder and the AIB manifest present in this folder. See https://sig.centos.org/automotive/getting-started/ for some getting-started documentation
- root partition to root partition demo
  - SSH into the VM with 2 terminals
    - In one terminal do:
    ```
    # go where the configuration files are:
    cd /usr/share/score-communication/examples/ipc_bridge/etc/
    # run the subscriber
    ipc_bridge_cpp --mode proxy --num-cycles 5 --cycle-time 1000 --service_instance_manifest mw_com_config.json
    ```
    - In the other terminal do:
    ```
    # go where the configuration files are:
    cd /usr/share/score-communication/examples/ipc_bridge/etc/
    # run the publisher
    ipc_bridge_cpp --mode skeleton --num-cycles 5 --cycle-time 1000 --service_instance_manifest mw_com_config.json
    ```
- Root partition to QM partition demo
  - SSH into the VM with 2 terminals
    - In one terminal do:
    ```
    # go inside the QM partition
    podman exec -ti qm bash
    # go where the configuration files are:
    cd /usr/share/score-communication/examples/ipc_bridge/etc/
    # run the subscriber
    ipc_bridge_cpp --mode proxy --num-cycles 5 --cycle-time 1000 --service_instance_manifest mw_com_config.json
    ```
    - In the other terminal do:
    ```
    # go where the configuration files are:
    cd /usr/share/score-communication/examples/ipc_bridge/etc/
    # run the publisher
    ipc_bridge_cpp --mode skeleton --num-cycles 5 --cycle-time 1000 --service_instance_manifest mw_com_config.json
    ```

