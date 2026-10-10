# TFTP operator manual

This manual covers Advanced TFTP 0.8.1 on Rocky Linux 8.10 and 10.2, from installation to removal. Start with the workflow below and use the reference pages for configuration details.

The intended reader administers Linux services. The installation and acceptance procedures provide the initial workflow; a separate tutorial would repeat those procedures.

## Installation and operating workflow

| Order | Task | Procedure | Completion criterion |
| --- | --- | --- | --- |
| 1 | Prepare packages and site settings | [Install the service](INSTALL.md), steps 1 and 2 | Dependencies and approved site settings are available. |
| 2 | Prepare the service user and group | [Install the service](INSTALL.md), step 3 | The configured service identity exists with nonzero UID and GID. |
| 3 | Prepare directories and permissions | [Install the service](INSTALL.md), step 4; [directory access](PERMISSIONS.md) | Program and published-data paths are separate; publication ownership and access are understood. |
| 4 | Build, install, and verify | [Install the service](INSTALL.md), steps 5 through 7 and Verification; [isolated tests](VERIFICATION.md) | Installed-state checks pass; destructive tests run only in a dedicated environment. |
| 5 | Test the deployment | [Accept the host](ACCEPTANCE.md) | Real client, maintenance, OS reboot, and applicable device checks pass on the intended host. |
| 6 | Operate the lifecycle | [Operate the service](USER_GUIDE.md) | Each selected scenario reaches its required final state and verification result. |

## Lifecycle procedures and references

| Reader goal | Authoritative page |
| --- | --- |
| Start, publish, replace, stop, resume, restart, or check reboot behavior | [Operating scenarios](USER_GUIDE.md) |
| Select and install another source version | [Program update](UPDATE.md) |
| Restore the recorded source and configuration | [Program recovery](RECOVERY.md) |
| Remove programs and units while retaining data | [Service removal](UNINSTALL.md) |
| Understand service identity, publication access, and write protection | [Directory ownership and access](PERMISSIONS.md) |
| Understand socket state, download probes, and monitoring limits | [Service monitoring boundaries](MONITORING.md) |
| Resolve configuration defaults and Make targets | [Configuration and commands](SERVICE.md) |
| Understand source, installation, and transfer data flow | [Service architecture](ARCHITECTURE.md) |
| Interpret terms and abbreviations | [Terms and abbreviations](GLOSSARY.md) |
| Generate the HTML manual | [Manual build](BUILD.md) |
| Resume planned work or inspect verification evidence | [Milestone record](milestone-dae25fe.md) |

The chapter navigation lists every manual page. Operating procedures define acceptance; the milestone record owns proposed changes and observed project results.
