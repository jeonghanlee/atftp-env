# TFTP verification procedures

Select checks for installed configuration, real service behavior, and client-network acceptance. Follow the [operator workflow](index.md) for the complete installation and operating order.

## Test classification and scope

| Check | Target | Execution context | Changes |
| --- | --- | --- | --- |
| `make service.check` | Installed options, identities, symlink target ownership and modes, unit policy, effective command and socket service, running executable, arguments, UID/GID and mounts, boot enablement | Installed server with sudo access | None |
| `tests/service.bash` | Socket activation, actual UID/GID, downloads, upload rejection, and stop/start | Dedicated systemd test server or disposable CI container, as root | Stops both units; publishes and removes uniquely named test files; leaves both units stopped |
| `tests/installation.bash` | Help discovery, data-root and command drift, socket endpoint and service overrides, retained socket consumers, executable symlinks and replacement, pending reloads, writable exceptions, retained root processes, mount state, and safe removal failure | Dedicated default-path systemd test host, as root | Changes configuration, programs and unit policy, tests uninstall, reinstalls, and leaves both units stopped |
| `tests/client.bash` | Exact bytes from a published file through the installed client | Server or actual network client, ordinary user | Temporary client download; the request can activate an idle server |
| `bash tests/network.bash` | Peer downloads, PUT rejection, idle activation, stop/start/restart, and container restart | Docker host with privileged-container support | Builds two images; creates and removes two containers and one network; retains images and logs |

The lifecycle suite executes the installed programs and real systemd units. It uses the shipped fixture in `tests/fixtures/download.txt`. It must not run against an operational service: it interrupts transfers and publishes a world-writable overwrite probe.

The client check sends only a download request and does not change server files. With an active systemd socket, the request can activate an idle server. Checks and tests use Bash 4.4 or later, coreutils, gawk, and diffutils. Client download checks also require an installed atftp client. The isolated suites use `lib.bash` for assertions and bounded execution; they run the installed Make targets, systemd units, and TFTP programs directly.

## Run verification in order

1. Complete the [installation procedure](INSTALL.md). Run server-side commands from the retained repository root.
2. Run `make service.check`; stop on any failed check.
3. On a dedicated systemd test host, run the lifecycle suite:

   ```bash
   sudo ./tests/service.bash
   ```

   Require exit status zero and the final `PASS` line. Both units remain stopped after the suite.

4. On the same dedicated host, run the installation regressions:

   ```bash
   sudo ./tests/installation.bash
   ```

   Require exit status zero and the final `PASS` line. This suite requires the default account, unit names, and paths; never run it on an operational service. It resets systemd failure and start-limit counters between independent activation cases.

5. On the intended deployment host, complete [host acceptance](ACCEPTANCE.md), including the real client network. Isolated test results cannot replace deployment acceptance.

## Check a published download

On the client, use Bash 4.4 or later, coreutils, diffutils, and an installed atftp client. From the client's test checkout root, use an independently approved copy of the published file:

```bash
./tests/client.bash --host <server_ip> --remote <published_file> --expected <approved_file>
```

Replace `<server_ip>` with the server address, `<published_file>` with its relative TFTP path, and `<approved_file>` with the local approved copy. The default client is `/opt/atftp/bin/atftp` and the default UDP port is 69. Use `--client` for another installed client path and `--port` for a non-default port.

Require exit status zero and `[PASS] download content matches`. A failed client command, timeout, missing output, or content mismatch exits nonzero. The check prints the byte count and SHA-256 digest of the matching content.

## Run peer network verification

This procedure exercises both supported servers through real TFTP transfers between separate containers.

Prerequisites: Bash, coreutils, a running Docker daemon accessible to your account, privileged-container support, and network access for image and source downloads.

From the repository root, execute the peer verification:

```bash
bash tests/network.bash
```

The script builds the current checkout with `.github/ci/Dockerfile` for Rocky 8.10 and 10.2. It uses a dedicated Docker network and tests both transfer directions with the shipped fixture.

The checks cover exact downloaded bytes, rejected new-file and overwrite PUT requests, unchanged server files, idle exit and socket reactivation, stopped-server failure, start/restart recovery, and socket activation after container restart.

Verification requires exit status zero and the final output:

```text
PASS: two-container TFTP network lifecycle
```

The script prints its evidence directory, `/tmp/atftp-network.<run_id>`. It retains `commands.log`, container logs named by container ID, and `cleanup.log` on success or failure. Cleanup removes the containers and network created by that run. Images `atftp-peer:8.10` and `atftp-peer:10.2` remain; subsequent runs rebuild these tags.

Container restart checks do not establish OS reboot behavior. This procedure does not exercise production firewall rules, SELinux policy, physical devices, or concurrent-load capacity.

## Results and verification limits

Retain OS version, source tag, site settings, endpoint, client location, output, and exit status for acceptance. Every mandatory check must pass; a missing prerequisite or an unexecuted check cannot count as success.

CI runs real systemd in disposable Rocky 8.10 and 10.2 containers. Those results cover installed state and local lifecycle behavior. They do not verify a deployment host's firewall, SELinux policy, OS reboot, external client network, or device firmware-loading behavior.

The isolated suites print assertion totals and retain their temporary workspace on failure. Set `KEEP_WORKSPACE=1` to retain it after success. The client check removes its temporary download on exit.
