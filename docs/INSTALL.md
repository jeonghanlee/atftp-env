# Install the TFTP service

Prepare a download-only Advanced TFTP service on Rocky Linux 8.10 or 10.2.
Run Make as the checkout owner; installation recipes use sudo internally.

## Prerequisites

- A supported host running systemd, with sudo access and package repository access.
- GitHub access for the upstream source checkout.
- An available listening address and UDP port; the default is all IPv4 interfaces on port 69.
- Approved client networks and firewall rules covering the complete TFTP exchange, including server-selected UDP transfer ports.
- On SELinux-enforcing hosts, an approved policy and contexts for the executable and published directory. Installation does not configure these.
- A fresh upstream checkout for the selected version. For an existing installation, use the update procedure in the [operator guide](USER_GUIDE.md).

## Prepare and install the service

1. Install the build and service packages:

   ```bash
   sudo dnf install git make sudo tree which autoconf automake gcc gcc-c++ glibc-devel libtool flex binutils systemd
   ```

   Installation checks and tests use Bash 4.4 or later, coreutils, gawk, and diffutils:

   ```bash
   sudo dnf install bash /usr/bin/timeout gawk diffutils
   ```

   The command selects the timeout provider supplied by coreutils or coreutils-single.

2. In `configure/CONFIG_SITE.local`, set site overrides before installation. Review the resolved variables in the [configuration reference](SERVICE.md). Keep programs and data on separate paths outside user home directories.

3. Prepare the service identity and published directory:

   ```bash
   make service.setup
   ```

   Missing `atftp:atftp` accounts are created without a login shell. Existing accounts remain unchanged; UID and GID zero are rejected. The default directory is `/srv/tftp`, owned by `root:atftp`, mode `0755`.

4. Fetch the selected upstream source:

   ```bash
   make init
   ```

5. Build the selected source:

   ```bash
   make build
   ```

6. Install the programs, configuration, and units:

   ```bash
   make install
   ```

   Installation repeats account and directory preparation, installs root-owned programs under `/opt/atftp`, and enables the socket at boot. It does not start the socket. Any failure stops acceptance; correct the reported condition before proceeding.

## Verification

Check installed state before starting the service:

```bash
make service.check
```

Require exit status zero and `PASS: installed service configuration`. This checks account IDs, directory ownership and mode, program ownership, executable presence, unit syntax, installed options, effective server command and configuration file, service identity, download-only protection, writable mount exceptions, socket endpoint, and boot enablement. When the server is running, it also checks actual process arguments, socket address and port, UID/GID, and read-only data mounts using sudo. The check does not change service state. Pending service or socket changes fail the live check; review and apply them with `make sd_reload` before repeating verification. Reload does not replace an existing server process; use `make sd_restart` to apply approved runtime changes.

Complete the [host acceptance procedure](../gate/RUNBOOK.md) before admitting operational clients. Installation checks alone do not establish network reachability or SELinux runtime access.

Program checks follow symlink targets and require root ownership without group or world write access on the executable and its parent directories. The live check verifies that the running executable is the installed file and that the socket activates only the approved service. A retained process from another service using the listening socket fails verification.
