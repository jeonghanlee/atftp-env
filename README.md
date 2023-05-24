# atfpd-env

[![Rocky8](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky8.yml)
[![Rocky9](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky9.yml/badge.svg)](https://github.com/jeonghanlee/atftp-env/actions/workflows/rocky9.yml)

Configuration Environment for the Advanced TFTP service at <https://github.com/madmartin/atftp>. This repository is designed for specifically the Rocky Linux, because Redhat variant does not have the atftp package as a `rpm` format. Please use the Debian package if one wants to use it within Debian variants and one **should not** use this repository on Debian variants.

## Rocky Linux (8, 9)

### Setup and Install Commands

```bash
make init
make conf
make build
make install
make exist
```

### Systemd related Commands

```
make sd_start
make sd_status
make sd_stop
```

### Uninstall, or reinstall with systemd services

```
make uninstall
make reinstall
```

### Check target location

```
make exist
tree -aL 1 /opt/atftp
/opt/atftp
├── atftpd.bash
├── atftpd.conf
├── bin
├── sbin
└── share

```

