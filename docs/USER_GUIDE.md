# Operate the TFTP service

Manage published files and the socket-activated server through the installed Make targets.

## Prerequisites

- A completed [installation](INSTALL.md) and [host acceptance](../gate/RUNBOOK.md).
- Sudo access for service control and publication.
- A retained checkout with the same site configuration as the installed service.
- A known client and expected file for download verification.

## Follow the operating procedure

1. Select the applicable scenario from the table below. Schedule interruption when the scenario stops the service; stop and restart can interrupt active transfers.

   | Scenario | Actions | Required final state |
   | --- | --- | --- |
   | Initial start | Run `make sd_start`, then the documented client check. | Socket active; download matches. |
   | Publish a file | Copy a root-owned, readable regular file into the published directory; run the client check. | Client receives the approved bytes. |
   | Replace a file | Stop both units, retain the approved previous file outside the published directory, replace the file, start, and run the client check. | Approved replacement downloads; previous content remains available for recovery. |
   | Restart service | Run `make sd_restart`, then the client check. | Socket active; downloads resume. |
   | Maintenance stop | Run `make sd_stop`; inspect both units. | Socket and service inactive. |
   | Resume operation | Run `make sd_start`, then the client check. | Socket active; downloads resume. |
   | OS reboot | Reboot during an approved window; inspect the enabled socket and run the client check afterward. | Socket activates at boot; client download succeeds. |
   | Update programs | Follow the [update procedure](UPDATE.md). | Installed version matches the selected release; downloads succeed. |
   | Recover after an update | Follow the [recovery procedure](RECOVERY.md). | Approved version serves the approved files. |
   | Remove service | Follow the [removal procedure](UNINSTALL.md). | Units and programs removed; published data retained. |

2. Execute the selected actions. For file publication using the default directory, install the approved file:

   ```bash
   sudo install -o root -g root -m 644 firmware.bin /srv/tftp/firmware.bin
   ```

   Use regular files and readable parent directories. Do not publish links outside the TFTP directory. Uploads and overwrites through TFTP are prohibited.

3. Inspect both unit states after the action:

   ```bash
   make sd_status
   ```

   An active socket with an inactive server is normal between requests. The server exits after the configured idle timeout. `sd_status` can return nonzero for that normal state; read each unit's state. If a required check fails, keep clients out of service until the approved configuration and content pass again.

## Verification

From an actual client on an approved network, execute the [download check](../tests/README.md). Require exit status zero and an exact content match after every publication, replacement, restart, reboot, or update.

A same-host download checks local operation. It does not establish reachability from the client network. A reboot scenario requires an actual OS reboot; restarting a unit cannot substitute for it.
