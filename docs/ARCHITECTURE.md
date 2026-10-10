# Architecture

## Overview

Advanced TFTP 0.8.1 serves files from a root-managed directory on Rocky Linux 8.10 and 10.2. systemd supplies the UDP socket and service identity. Uploads are prohibited by the service's read-only filesystem view.

## Provisioning Flow

```text
configure/RELEASE -> upstream v0.8.1 -> build -> /opt/atftp
configure/CONFIG_SITE -> templates -> configuration and systemd units
service.setup -> atftp account and /srv/tftp
atftpd.socket -> UDP request -> atftpd.service -> published file -> client
```

## Directory Structure

```text
/opt/atftp/                 root:root, programs and configuration
  bin/atftp                client
  sbin/atftpd              server
  atftpd.conf              server options, root:root 0644
  atftpd.bash              systemd control wrapper, root:root 0755
/etc/systemd/system/       root-owned service and socket units
/srv/tftp/                 root:atftp 0755, published data
```

## Network

The default socket listens on all IPv4 interfaces at UDP port 69. TFTP transfers also use server-selected UDP transfer ports. Deployment network and firewall rules must permit the TFTP exchange; this repository does not alter host firewall rules.

## Component Architecture

`atftpd.socket` owns the listening endpoint and is enabled for boot. `atftpd.service` consumes the socket through standard input and runs with explicit `User` and `Group` settings. The server uses its inetd-compatible mode; `--daemon`, `--user`, `--group`, and `--port` are not included in the service options.

The service uses `NoNewPrivileges`, `ProtectSystem=strict`, `ReadOnlyPaths` for its TFTP directory, `ProtectHome`, and `PrivateTmp`. A writable file inside the TFTP directory remains read-only inside the service. Published symlinks must not point outside the intended data directory; the server is not a chroot environment.

Programs and configuration remain root-owned. Installation creates the service identity and data directory before installing units. Uninstall preserves published data and the service identity.

## OS and Platform Differences

| Concern | Rocky 8.10 | Rocky 10.2 |
| --- | --- | --- |
| Package installation | dnf | dnf |
| Service manager | systemd | systemd |
| CI base image | rockylinux/rockylinux:8.10 | rockylinux/rockylinux:10.2 |

## Variable Scoping

| File | Values |
| --- | --- |
| configure/RELEASE | Upstream URL, tag, and version |
| configure/CONFIG_SITE | Installation path, identity, endpoint, and TFTP options |
| configure/CONFIG_SYSTEMD | Derived unit filenames |
| configure/CONFIG_VARS | Derived source path and documentation URL |
| configure/*.local | Local overrides, excluded from Docker builds |
