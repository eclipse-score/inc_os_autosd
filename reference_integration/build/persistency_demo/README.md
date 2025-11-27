persistency_demo
================

This demo build an AutoSD image using [Automotive-Image-Builder](https://gitlab.com/CentOS/automotive/src/automotive-image-builder).
This image comes pre-populated with the S-core's [persistency](https://github.com/eclipse-score/persistency) project packaged as RPM in a [COPR](https://copr.fedorainfracloud.org/coprs/pingou/score-playground/) repository as well as the [QM](https://github.com/containers/qm) project. The demno program showing persistency's capabilities can be found in the [persistency-demo](https://github.com/pypingou/persistency-demo) project, itself packaged in [its own COPR repository](https://copr.fedorainfracloud.org/coprs/pingou/persistency-demo/).

The image is pre-configured to allow the communication project to send and receive messages within the root partition but also between the root partition and the QM partition.


Some things to know about this demo:
- The RPM packaging, currently, doesn't rely on Bazel. This is something that is being fixed, but in the current stage it is not there yet.


To run the demo:
- Build the AutoSD image using Automotive-Image-Builder and the AIB manifest present in this folder. See https://sig.centos.org/automotive/getting-started/ for some getting-started documentation
- C++ demo, in the host partition
  - Log into the system and run the command:
    ```
    kvs-cpp-demo
    ```
- Rust demo, in the QM partition
  - Log into the system and then into the QM partition using:
    ```
    podman exec -ti qm bash
    ```
  - From there, you can run the Rust demo. Note the QM partition is mounted as read-only by default, so for the demo to work you need to ask it to create its files in the `/tmp` partition:
    ```
    kvs-rust-demo /tmp/data
    ```

