# atfpd-env

Configuration Environment for the Advanced TFTP service at <https://github.com/madmartin/atftp>. This repository is designed for specifically the Rocky Linux, because Redhat variant does not have the atftp package as `rpm` format. Please use the Debian package if one wants to use it within Debian variants.

## Rocky 8


```bash
make init
make conf
make build
make install
make exist
```

```
make sd_start
make sd_status
```

```
make reinstall
```

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





