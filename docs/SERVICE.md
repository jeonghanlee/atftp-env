# Service configuration and commands

Resolve defaults and control behavior here; use the [operator manual](index.md) for execution order.

## Site configuration values

Create `configure/CONFIG_SITE.local` for site overrides before installation. Installation and runtime configuration must use the same values.

| Variable | Default | Meaning |
| --- | --- | --- |
| INSTALL_PATH | /opt | Program installation parent |
| USERID | atftp | Unprivileged service user |
| GROUPID | atftp | Unprivileged service group |
| TFTPD_DIR | /srv/tftp | Published file directory |
| TFTPD_DIR_MODE | 0755 | Root-owned directory permissions |
| TFTPD_ADDRESS | 0.0.0.0 | IPv4 listening address |
| TFTPD_PORT | 69 | UDP listening port |
| TFTPD_TIMEOUT | 300 | Server idle timeout in seconds |
| RETRY_TIMEOUT | 5 | Transfer retry timeout in seconds |
| MAXTHREAD | 100 | Maximum concurrent transfer threads |
| TFTPD_VERBOSE | 100 | Server verbosity level |
| SYSTEMD_RELOAD | 1 | Reload the live manager after unit installation |

Source version overrides belong in `configure/RELEASE.local`. The [directory access reference](PERMISSIONS.md) defines account preparation, ownership, and publication responsibilities.

The default endpoint is IPv4. Configure a specific IPv4 address with `TFTPD_ADDRESS` when required. Local paths and identity names must be valid for Make, shell commands, and systemd; use paths without whitespace or template delimiter characters.

## Service control reference

| Target | Result |
| --- | --- |
| `service.setup` | Create missing identity entries and prepare the data directory |
| `service.check` | Inspect installed options and policy, effective command and socket endpoint, actual running arguments, UID/GID and data mounts, and boot enablement |
| `sd_start` | Reload systemd and start the socket |
| `sd_stop` | Stop socket and server; fail on stop errors or a unit that remains active |
| `sd_restart` | Stop both units, then start the socket |
| `sd_status` | Report both units; can return nonzero when the server is idle |
| `sd_enable` | Enable the socket for boot |
| `sd_disable` | Disable both units for boot |
| `uninstall` | Remove units and programs while preserving published data and accounts |
| `reinstall` | Uninstall and install; leave the socket stopped |

The installed `/opt/atftp/atftpd.bash` wrapper accepts `start`, `stop`, `restart`, `reload`, and `status`. Its `reload` restarts both units rather than sending a daemon signal. Restart and stop can interrupt active transfers.

A request activates the server. After its configured idle timeout, the server exits and the socket remains active. The socket controls boot activation; the service unit is static.

`SYSTEMD_RELOAD=0` is for offline image installation. It skips the live manager reload while retaining unit installation and boot enablement. For an offline image, pass it to `make service.check` as well; the check verifies installed unit files without querying live service properties. Live host acceptance must use the default value `1`.

Use the [installation procedure](INSTALL.md), [operator scenarios](USER_GUIDE.md), and [verification procedures](VERIFICATION.md) for execution order and acceptance criteria.

The installed `OPTIONS` assignment must match the resolved site configuration and end with `TFTPD_DIR`. The running server arguments must match those options. Both service and socket units must have no pending reload; the effective socket must contain exactly the configured UDP endpoint with `Accept=no`. The active server's standard-input socket must use that same endpoint. Use `make help` to find `service.setup` and `service.check`.

Use one single-quoted or double-quoted `OPTIONS` assignment matching the generated value; the check reads configuration as data without executing it. The socket's `Service` setting and effective `Triggers` must identify the approved service. Program symlink targets and their parent directories must be root-owned without group or world write access. A running executable that differs from the installed file, or another process retaining the server socket, fails the live check.

The service profile prohibits explicit `ReadWritePaths`, writable `BindPaths`, `TemporaryFileSystem`, `RootDirectory`, and `RootImage` overrides. `PrivateTmp` supplies the service's temporary storage. Installation checks reject these overrides in the installed unit and live configuration. Active servers must also have the configured process identity and read-only mounts covering the published directory and its descendants. Runtime inspection requires sudo and changes no state. A process transition fails verification; repeat the check after the unit reaches a stable state.

## Related operating boundaries

See [directory ownership and access](PERMISSIONS.md) for host publication and recursive-policy limits. See [service monitoring boundaries](MONITORING.md) for socket state, real-download probes, and concurrent-transfer limits.

Proposed policy, monitoring design, and capacity measurements belong to the [milestone record](milestone-dae25fe.md).
