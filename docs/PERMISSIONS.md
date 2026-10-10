# Directory ownership and access

The service reads published files using its configured user and group. Local filesystem permissions control that access; the systemd service supplies a read-only view of published data.

## Installed ownership and modes

Defaults apply unless the retained site configuration overrides them.

| Object | Owner and group | Mode or requirement | Managed by |
| --- | --- | --- | --- |
| Service identity | User `atftp`, group `atftp` | Nonzero user ID (UID) and group ID (GID); missing users receive a non-login shell | `service.setup` |
| Program installation | `root:root` | No group or world write access; executable targets and parent directories must be protected | Installation and `service.check` |
| Server configuration | `root:root` | Generated `atftpd.conf`: `0644` | `conf_install` |
| Control wrapper | `root:root` | Generated `atftpd.bash`: `0755` | `conf_install` |
| Published root | `root:atftp` | Default `/srv/tftp`: `0755`; the root itself must not be a symlink | `service.setup` |
| Published file | `root:root` in the publication example | `0644`; readable by the service identity | Operator |
| Published subdirectory | Operator-managed | Traversable by the service identity; ownership and mode require operator inspection | Operator |

Preparing the service creates missing accounts and applies ownership and mode to the published root. Existing accounts remain unchanged. Preparation does not recursively repair published files or subdirectories.

## Publication and access boundaries

Root publishes files through the [operating procedure](USER_GUIDE.md). File replacement includes a maintenance stop and an approved recovery copy outside the published tree.

The service identity needs read access to each file and traversal access to its parent directories. Use regular files and do not publish symlinks outside the intended data tree. The server does not run in a chroot environment.

`ProtectSystem=strict` and `ReadOnlyPaths` prohibit TFTP writes to the published tree, including files that are writable on the host. These protections do not prevent a local publisher from changing host files.

Unix permissions do not authenticate TFTP clients. The default `0755` directory and `0644` file modes also allow other local users to read published files. Approved network access depends on deployment firewall policy.

## Checks and proposed changes

`service.check` verifies the published root's ownership and mode. It checks program ownership, installed and live service policy, and a running server's identity and read-only data mounts.

It does not recursively validate every published file, symlink, or access control list (ACL). Operators must inspect descendants before publication and verify approved bytes through a real client download.

A stricter recursive policy, including the proposed `root:atftp` directory mode `0750` and file mode `0640`, belongs to the [milestone record](milestone-dae25fe.md). Those proposals do not change the installed defaults.
