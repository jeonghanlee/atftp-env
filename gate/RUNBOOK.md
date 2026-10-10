# Accept a deployed TFTP host

Establish that an installed download-only service operates on its intended host and client network.

## Prerequisites

- A completed [installation](../docs/INSTALL.md) on Rocky Linux 8.10 or 10.2.
- Sudo access on the server, an approved interruption window, and an actual network client.
- Approved firewall rules for the complete TFTP exchange and applicable SELinux policy and file contexts.
- Bash 4.4 or later, coreutils, diffutils for `cmp`, the test checkout, and an installed atftp client on the client host.
- An independently approved test file available on both hosts.

## Execute host acceptance in order

1. Record the server OS, installed client and server versions, selected source tag, site overrides, listening endpoint, and client network. Require the configured version and supported OS.
2. Inspect listening-port use, firewall policy, SELinux mode and contexts, service identities, and data permissions. Resolve competing TFTP services before starting this socket. Keep SELinux and the firewall in their intended operational state throughout acceptance.
3. Validate installed state:

   ```bash
   make service.check
   ```

4. Publish the approved fixture on the server using the default data directory:

   ```bash
   sudo install -o root -g root -m 644 tests/fixtures/download.txt /srv/tftp/validation.txt
   ```

   For a custom directory, use the configured path. Retain the fixture independently on the client.

5. Start the socket:

   ```bash
   make sd_start
   ```

6. From the actual client, verify the published file:

   ```bash
   ./tests/client.bash --host <server_ip> --remote validation.txt --expected tests/fixtures/download.txt
   ```

   Replace `<server_ip>` with the deployment address. Require an exact content match. The same command from the server is only a local check.

7. During the approved window, exercise maintenance stop, resume, and restart using the [operator scenarios](../docs/USER_GUIDE.md). Require both units inactive after stop and a successful client check after resume and restart.
8. Exercise an actual OS reboot. Require socket boot activation and repeat the client download afterward.
9. If device firmware loading is part of deployment, run the actual device procedure using its approved file and verify the device's resulting version or ready state. A desktop client download cannot substitute for this check.

## Verification

Accept the host only when every applicable mandatory step passes against one unchanged installation and site configuration. Retain each step's output and exit status, final unit states, client content digest, and any device result.

If a prerequisite is missing or a step is unexecuted, record acceptance as incomplete. Container CI or an earlier installation cannot fill that gap. On failure, stop operational admission and follow the approved recovery scenario before repeating acceptance.
