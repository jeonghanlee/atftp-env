# Update the TFTP programs

Replace the installed programs while retaining an approved recovery copy of the source identity and configuration. Use this procedure for the update scenario in the [service lifecycle](USER_GUIDE.md).

## Prerequisites

- A working, accepted installation and an approved interruption window.
- Sudo access, a clean upstream source checkout, and access to the selected source tag.
- The checkout owner runs these steps from the `atftp-env` repository root.
- These commands use the default source and installation paths. Replace them with the recorded site paths when overrides apply.
- A unique backup identifier and sufficient private backup storage outside the published directory.
- An approved client file for the final [download check](VERIFICATION.md).

## Apply the selected source version

1. Set the checkout and private backup paths:

   ```bash
   atftp_repo=$(pwd)
   atftp_backup="$HOME/atftp-backup-<backup_id>"
   ```

   Replace `<backup_id>` with a unique identifier for this update. Keep these variables for the complete procedure.

2. Confirm that the upstream checkout has no modified or untracked files:

   ```bash
   git -C "$atftp_repo/atftp-src" status --porcelain
   ```

   Require empty output. Stop if local source changes exist; retain and review them before selecting another version.

3. Create the private backup directory:

   ```bash
   mkdir -m 700 "$atftp_backup"
   ```

   Require success; an existing backup directory must not be overwritten.

4. Preserve the current configuration:

   ```bash
   cp -a configure "$atftp_backup/"
   cp -a /opt/atftp/atftpd.conf "$atftp_backup/"
   ```

   Also retain any overrides loaded from the parent directory and record their original absolute paths. Keep this recovery record unchanged during the update.

5. Record the upstream commit to restore:

   ```bash
   git -C "$atftp_repo/atftp-src" rev-parse HEAD > "$atftp_backup/source-commit.txt"
   ```

6. Stop both units before changing the installed programs:

   ```bash
   make sd_stop
   ```

   Require exit status zero. A failed stop prohibits build installation and removal.

7. In `configure/RELEASE.local`, set the approved `SRC_TAG` and `SRC_VERSION`, then select that tag in the upstream checkout. For version 0.8.1, fetch and select it:

   ```bash
   git -C "$atftp_repo/atftp-src" fetch --tags
   git -C "$atftp_repo/atftp-src" checkout --detach v0.8.1
   ```

   Replace `v0.8.1` when another version is approved. `make init` is for creating a fresh source checkout and cannot update an existing one.

8. Build the selected version:

   ```bash
   make build
   ```

9. Install the programs and matching service configuration:

   ```bash
   make install
   ```

10. Check the installation:

    ```bash
    make service.check
    /opt/atftp/bin/atftp --version
    /opt/atftp/sbin/atftpd --version
    ```

    Require every command to exit zero, the installation check to pass, and both versions to match `SRC_VERSION`. On failure, leave clients stopped and use the [recovery procedure](RECOVERY.md).

11. Start the socket:

    ```bash
    make sd_start
    ```

## Verification

From the approved client network, execute the [download check](VERIFICATION.md) using the approved file. Require exit status zero and an exact content match before returning the service to operation. Retain the backup until the update is accepted.
