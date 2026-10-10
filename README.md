# atftp-env

[![Rocky8.10](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml)
[![Rocky10.2](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky10.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky10.yml)

Build and service configuration for Advanced TFTP 0.8.1 on Rocky Linux 8.10 and 10.2. The service provides downloads only. On Debian variants, use the distribution's atftp package.

- [Installation](docs/INSTALL.md)
- [Operating scenarios](docs/USER_GUIDE.md)
- [Verification procedures](tests/README.md)
- [Host acceptance](gate/RUNBOOK.md)
- [Documentation index](docs/README.md)

## Installation and operation

Follow the [installation procedure](docs/INSTALL.md) for packages, service identity, directories, permissions, and installation checks. Run Make as the checkout owner with sudo access; recipes invoke sudo internally.

Installation enables `atftpd.socket` at boot and leaves it stopped. An active socket with an inactive server is normal between requests. Use the [operator scenarios](docs/USER_GUIDE.md) for publication, service control, updates, reboot checks, and recovery.

## Verification and acceptance

The [test procedures](tests/README.md) distinguish installed-state checks, isolated lifecycle tests, and downloads from actual network clients. The [host acceptance runbook](gate/RUNBOOK.md) defines the ordered deployment checks and evidence requirements.

CI builds each supported Rocky image, installs the programs and units, and runs real systemd in a privileged disposable container. It verifies socket activation, actual server UID/GID, download contents, upload and overwrite rejection, and stop/start behavior. Deployment firewall, SELinux, OS reboot, and device behavior require host acceptance.
