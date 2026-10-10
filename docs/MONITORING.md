# Service monitoring boundaries

The repository provides on-demand configuration checks and actual Trivial File Transfer Protocol (TFTP) downloads. It does not install a periodic monitor.

## Select the appropriate observation

| Observation | Interface | What it establishes | What it does not establish |
| --- | --- | --- | --- |
| Installed configuration | `make service.check` | Installed options, identity, ownership, effective units, endpoint, and boot enablement agree with site settings | Successful transfer from a client network |
| Running server policy | `make service.check` while the server runs | Actual executable, arguments, identity, socket endpoint, and read-only published-data mounts agree | Free disk space or transfer capacity |
| Unit state | `make sd_status` | Current systemd socket and service states | Correct downloaded contents |
| File availability | [Client download check](VERIFICATION.md#check-a-published-download) | The probe location can download the approved bytes | Health of every published file, internal process health, or simultaneous-device capacity |

## Interpret socket activation state

An active `atftpd.socket` with an inactive `atftpd.service` is normal between requests. A download request can start the server, which exits after its configured idle timeout.

An active server alone does not establish successful downloads. Conversely, an inactive server alone does not establish an outage. Evaluate the socket state and use a real client download for transfer availability.

`sd_status` can return nonzero when one unit is inactive. Read both reported states. `service.check` is a configuration acceptance check; it is not a standalone availability alarm.

## Monitoring and capacity limits

TFTP uses User Datagram Protocol (UDP). The repository supplies no Hypertext Transfer Protocol (HTTP) status API and no EPICS Input/Output Controller (IOC) for monitoring.

A periodic download probe needs an endpoint, approved file, expected contents, interval, timeout, and a defined response to failed or stale results. Disk capacity and other host-resource observations require separate checks.

`MAXTHREAD=100` limits concurrent server threads; it does not guarantee completion for 100 devices. Capacity depends on file sizes, client options, network conditions, server resources, and retransmissions.

The [milestone record](milestone-dae25fe.md) owns the proposed IOC design and simultaneous-boot measurement plan. Container functional verification does not establish production-device capacity.
