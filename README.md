# atftp-env

[![Rocky8.10](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml)
[![Rocky10.2](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky10.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky10.yml)

Build and service configuration for Advanced Trivial File Transfer Protocol (TFTP) 0.8.1 on Rocky Linux 8.10 and 10.2. The service provides downloads only. On Debian variants, use the distribution's atftp package.

## Installation and operating sequence

Start with the [operator manual](docs/index.md), which connects these tasks:

1. Install required packages and review site settings.
2. Prepare the service user and group.
3. Prepare directories and review publication permissions.
4. Build, install, and verify the service in the appropriate test environment.
5. Accept the deployment on its actual host and client network.
6. Follow the operating lifecycle for publication, maintenance, update, recovery, and removal.

The [table of contents](docs/SUMMARY.md) links every procedure and reference. Run Make from the repository root as the checkout owner with sudo access; recipes invoke sudo internally.

The [manual build procedure](docs/BUILD.md) generates an HTML edition with mdBook. All manual sources reside in `docs/`.

## Verification and implementation boundaries

Continuous integration (CI) builds both supported Rocky images and runs installed programs with real systemd in privileged disposable containers. The [verification procedures](docs/VERIFICATION.md) distinguish those tests from deployment acceptance.

Production firewall rules, SELinux policy, OS reboot, and actual-device behavior require the [host acceptance procedure](docs/ACCEPTANCE.md). Container transfer tests do not establish concurrent-device capacity.

See [directory access](docs/PERMISSIONS.md) for the implemented ownership rules, [monitoring boundaries](docs/MONITORING.md) for the available observations, and the [milestone record](docs/milestone-dae25fe.md) for proposed work.
