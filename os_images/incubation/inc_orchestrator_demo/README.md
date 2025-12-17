inc_orchestrator_demo
=====================

This demo build an AutoSD image using [Automotive-Image-Builder](https://gitlab.com/CentOS/automotive/src/automotive-image-builder).
This image comes pre-populated with the S-core's [inc_orchestrator](https://github.com/eclipse-score/inc_orchestrator) project packaged as RPM in a [COPR](https://copr.fedorainfracloud.org/coprs/pingou/score-playground/) repository as well as the [QM](https://github.com/containers/qm) project.

The image comes with two example programs allowing to start processes on the system using inc_orchestrator.
The simplest program is `process_launcher`, the more interesting one is `holden_integration` which uses the holden agent from the [holden](https://github.com/pypingou/holden) project. That agent is responsible for launching processes in the QM partition and handing over a pid file descriptor (pidfd) for the program triggering it to monitor and act on the process started.


Some things to know about this demo:
- The RPM packaging, currently, doesn't rely on Bazel. This is something that is being fixed, but in the current stage it is not there yet.
- The communication between `holden_integration` and the `holden-agent` happens through an unix-domain socket that's running at `/run/holden/qm_orchestrator.sock` and mounted in the QM partition. This is not the default location where `holden_integration` is looking for that unix-domain socket, so it needs to be specified using the environment variable `HOLDEN_SOCKET_PATH`.
- Baselibs and inc_orchestrator have had to get some patches, some of which have already been sent upstream:
  - Missing headers: https://github.com/eclipse-score/baselibs/pull/19
  - Compilation issues on newer GCC + support for Linux ARM64: https://github.com/eclipse-score/baselibs/pull/22
- Other changes have not yet been sent upstream:
  - Make inc_orchestrator compatible with the rust version available in EPEL9/CentOS stream 9
  - Add the two example programs referred to above
  - Those changes can be found in: 


To run the demo:
- Build the AutoSD image using Automotive-Image-Builder and the AIB manifest present in this folder. See https://sig.centos.org/automotive/getting-started/ for some getting-started documentation
- root partition to root partition demo
  - SSH into the VM with 2 terminals
    - In one terminal do:
    ```
    # Watch if there are "sleep" processes running
    watch -n 1 "ps aux |grep sleep"
    ```
    - In the other terminal run a few different holden_integration commands:
    ```
    holden_integration --once "date"
    holden_integration --loop 'date +"%H:%M:%S.%N"'
    holden_integration --loop --frequency=1000 'date +"%H:%M:%S.%N"'
    holden_integration --every=1500 'date +"%H:%M:%S.%N"'

    holden_integration --once "sleep 5"
    holden_integration --loop "sleep 2"
    holden_integration --every=1500 "sleep 2"
    ```
    With the last three commands, you should see the `sleep` commands appear in the output of the `ps aux` that's running in the other terminal.
- Root partition to QM partition demo
  - SSH into the VM with 2 terminals
    - In one terminal do:
    ```
    # watch all the processes running in the QM partition
    podman exec -ti qm watch -n 1 "ps aux"
    ```
    - In the other terminal run a few holden_integration commands
    ```
    HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden_integration --qm --once "sleep 5"
    HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden_integration --qm --loop "sleep 2"
    HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden_integration --qm --every=1500 "sleep 2"
    ```
    The `sleep` commands are more interesting here since it allows you to see them in the output of the `ps aux` command you're running in the QM partition in the other terminal.

