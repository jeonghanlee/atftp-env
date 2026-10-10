# Remove the TFTP service

Remove installed programs and service units while preserving published data and the service identity.

## Prerequisites

- Sudo access and the checkout used for installation, including its site overrides and upstream build tree.
- Commands run from that repository root.
- An approved interruption window and retained configuration and published files.
- Independently retained approved copies of published files for content comparison.
- The checks below use default paths, unit names, and accounts; substitute the recorded site values for a custom installation.

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

Check that systemd cannot load either removed unit:

```bash
test "$(systemctl show atftpd.socket --property=LoadState --value)" = not-found
test "$(systemctl show atftpd.service --property=LoadState --value)" = not-found
```

Require exit status zero from each assertion. `not-found` is the expected load state after removal; `inactive` alone does not prove removal.

Check that the unit files and program installation are absent:

```bash
test ! -e /etc/systemd/system/atftpd.socket
test ! -e /etc/systemd/system/atftpd.service
test ! -e /opt/atftp
```

Require exit status zero from each command and no output.

Check that the published directory and service identity remain:

```bash
test -d /srv/tftp
getent passwd atftp
getent group atftp
```

Require exit status zero from every command. The account queries print the retained user and group entries.

Compare each retained published file with its independently approved copy:

```bash
cmp -- /srv/tftp/<published_file> <approved_file>
```

Replace `<published_file>` with the relative published path and `<approved_file>` with its approved local copy. Require exit status zero and no output for every file.

A failed check leaves removal acceptance incomplete. Do not require a successful TFTP download after removal.
