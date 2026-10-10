# Remove the TFTP service

Remove installed programs and service units while preserving published data and the service identity.

## Prerequisites

- Sudo access and the checkout used for installation, including its site overrides and upstream build tree.
- An approved interruption window and retained configuration and published files.

## Remove the installed service

1. Stop accepting requests:

   ```bash
   make sd_stop
   ```

2. Remove the installation:

   ```bash
   make uninstall
   ```

   The target stops and disables both units, removes their files and the program installation, and reloads systemd. It retains the TFTP directory, published files, and service account.

## Verification

Confirm that both units are absent from systemd and the program installation is absent. Compare retained published files with their approved copies and confirm that the service account remains present. A failed removal is incomplete; do not report the service as removed until all required checks succeed.
