# Restore the approved TFTP installation

Rebuild the recorded source commit with the preserved configuration when an update fails acceptance.

## Prerequisites

- The complete, unchanged backup from the [update procedure](UPDATE.md), including any parent-directory overrides.
- The retained repository and upstream checkout, sudo access, and an approved interruption window.
- The checkout owner runs these steps from the `atftp-env` repository root.
- An independently approved published file for client verification.
- Commands use default source and installation paths; use the recorded site paths for a custom installation.

## Restore the recorded source and configuration

1. Set the repository and existing backup paths:

   ```bash
   atftp_repo=$(pwd)
   atftp_backup="$HOME/atftp-backup-<backup_id>"
   ```

   Replace `<backup_id>` with the identifier of the approved recovery copy. Do not use a backup from another installation.

2. Stop both units:

   ```bash
   make sd_stop
   ```

   Require exit status zero. If stop fails, resolve that failure before replacing files.

3. Preserve the failed configuration before restoring the approved copy:

   ```bash
   mv configure "$atftp_backup/failed-configure"
   cp -a "$atftp_backup/configure" configure
   ```

   Require that `failed-configure` does not exist before this step. Restore any recorded parent-directory overrides to their original paths as well.

4. Confirm that the upstream checkout has no local changes:

   ```bash
   git -C "$atftp_repo/atftp-src" status --porcelain
   ```

   Require empty output before selecting the recorded commit.

5. Select the source commit recorded before the update:

   ```bash
   atftp_source_ref=$(cat "$atftp_backup/source-commit.txt")
   git -C "$atftp_repo/atftp-src" checkout --detach "$atftp_source_ref"
   ```

6. Rebuild the approved programs:

   ```bash
   make build
   ```

7. Install the rebuilt programs and restored configuration:

   ```bash
   make install
   ```

8. Verify installed state and versions:

   ```bash
   make service.check
   /opt/atftp/bin/atftp --version
   /opt/atftp/sbin/atftpd --version
   ```

   Require every command to exit zero and both program versions to match the restored `SRC_VERSION`. A failed check keeps the service out of operation.

9. Start the socket:

   ```bash
   make sd_start
   ```

## Verification

From the approved client network, execute the [download check](../tests/README.md) against an independently approved file. Require an exact content match before admitting operational clients. Program recovery retains published data; restore damaged data separately from its approved copy before this check.
