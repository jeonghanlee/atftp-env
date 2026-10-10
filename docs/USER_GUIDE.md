# Operate the TFTP service

Manage published files and the socket-activated server through the installed Make targets.

## Prerequisites

- A completed [installation](INSTALL.md).
- Completed [host acceptance](ACCEPTANCE.md) before admitting operational clients. During acceptance, exercise the same scenarios within its approved interruption window.
- Sudo access for service control and publication.
- Commands run from the retained repository root with the same site configuration as the installed service.
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

   Apply the [directory access rules](PERMISSIONS.md). Use regular files and readable parent directories; do not publish links outside the TFTP directory. TFTP uploads and overwrites are prohibited.

3. For scenarios that retain the installed service, inspect both unit states after the action:

   ```bash
   make sd_status
   ```

   Interpret socket and server states using [monitoring boundaries](MONITORING.md). `sd_status` can return nonzero when the server is idle; read each unit's state. If a required check fails, keep clients out of service until the approved configuration and content pass again.

   For service removal, use the [removal verification](UNINSTALL.md#verification) instead. Removed units are expected to be absent.

## Verification

Select the verification that matches the scenario:

| Scenario | Required verification |
| --- | --- |
| Initial start, publication, replacement, restart, resume, reboot, update, or recovery | From an actual client on an approved network, run the [download check](VERIFICATION.md). Require exit status zero and an exact content match. |
| Maintenance stop | Require both socket and service states to be `inactive`. Download success is not expected while stopped. |
| Service removal | Complete the [removal verification](UNINSTALL.md#verification). Require absent units and programs, retained data, and retained service identity. |

A same-host download checks local operation. It does not establish reachability from the client network. A reboot scenario requires an actual OS reboot; restarting a unit cannot substitute for it.
