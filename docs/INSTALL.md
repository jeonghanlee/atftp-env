# Install the TFTP service

Prepare a download-only Advanced TFTP service on Rocky Linux 8.10 or 10.2.
Run commands from the `atftp-env` repository root as the checkout owner. Make recipes use sudo internally.

## Prerequisites

- A supported host running systemd, with sudo access and package repository access.
- GitHub access for the upstream source checkout.
- An available listening address and UDP port; the default is all IPv4 interfaces on port 69.
- Approved client networks and firewall rules covering the complete TFTP exchange, including server-selected UDP transfer ports.
- On SELinux-enforcing hosts, an approved policy and contexts for the executable and published directory. Installation does not configure these.
- For initial installation, an environment checkout without an existing `atftp-src` directory. `make init` creates that upstream checkout.
- For an existing installation, use the [update procedure](UPDATE.md).

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

3. Prepare the service user and group, together with the published root:

   ```bash
   make service.setup
   ```

   Missing `atftp:atftp` accounts are created without a login shell. Existing accounts remain unchanged; user ID (UID) and group ID (GID) zero are rejected.

4. Review the prepared directory against [directory ownership and access](PERMISSIONS.md). The default published root is `/srv/tftp`, owned by `root:atftp`, mode `0755`. Preparation does not recursively change existing files. Keep programs and published data on separate paths.

5. Fetch the selected upstream source:

   ```bash
   make init
   ```

6. Build the selected source:

   ```bash
   make build
   ```

7. Install the programs, configuration, and units:

   ```bash
   make install
   ```

   Installation repeats account and directory preparation, installs root-owned programs under `/opt/atftp`, and enables the socket at boot. It does not start the socket. Any failure stops acceptance; correct the reported condition before proceeding.

## Verification

Check installed state before starting the service:

```bash
make service.check
```

Require exit status zero and `PASS: installed service configuration`. The [configuration reference](SERVICE.md) defines the installed and live properties checked.

The check does not start the socket or change service state. For initial installation, an enabled but stopped socket is expected. Installation checks do not establish client-network reachability or SELinux runtime access.

On a dedicated test system, follow the [verification procedures](VERIFICATION.md). Before admitting operational clients, complete [host acceptance](ACCEPTANCE.md) on the intended deployment.
