# TFTP work register

Release line: master
Milestone index: dae25fe
Canonical path: `docs/milestone-dae25fe.md`
Canonical branch or ref: master
Git upstream: origin/master
Remote tracker: none

Next session entry point: `docs/milestone-dae25fe.md`, M3; review the published-directory policy before implementation. M4 and M5 remain separate design and measurement-plan work.

This document separates implemented behavior, observed verification, and proposed work. The baseline is recorded in commits d1a4981, 6db0cc8, and b1f4d13. Container results do not establish production-host acceptance or concurrent-device capacity.

## Milestone

### Work

| ID | Work unit | Type | Status | Ready | Deps | Done when / Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | Download-only service baseline | Milestone | Complete | No | none | Implemented service and Bash verification; container checks passed. [Detail](#m1---download-only-service-baseline). |
| M2 | Document and prepare baseline commit | Milestone | Complete | No | M1 | Baseline documentation and commit preparation completed; three commits published on 2026-10-10. [Detail](#m2---document-and-prepare-baseline-commit). |
| M3 | Published directory policy | Milestone | Not started | Yes | none | Reviewable policy defines ownership, publication, and recursive checks. [Detail](#m3---published-directory-policy). |
| M4 | EPICS IOC monitoring design | Milestone | Not started | Yes | none | Reviewable design defines real TFTP probes, PVs, alarms, and failure tests. [Detail](#m4---epics-ioc-monitoring-design). |
| M5 | Concurrent boot capacity plan | Milestone | Not started | Yes | none | Approved measurement criteria and repeatable real-client load procedure. [Detail](#m5---concurrent-boot-capacity-plan). |
| G1 | Representative device information and access | External gate | Open | No | none | Device owners provide boot information and access to representative BLM and PSC devices. [Detail](#g1---representative-device-information-and-access). |
| M6 | U-Boot device acceptance | Milestone | Blocked | No | G1 | Actual downloads, boot, and recovery meet device-specific criteria. [Detail](#m6---u-boot-device-acceptance). |

### Decisions

| ID | Decision | Decision Date |
| --- | --- | --- |
| D1 | Prepare the implemented baseline and its documentation before implementing the next-stage proposals. | 2026-10-09 |
| D2 | Record concurrent-device performance as work requiring measurement, without asserting a guaranteed device count. | 2026-10-09 |

### Milestone Details

#### M1 - Download-only service baseline

Origin: dae25fe / M1
Identity History: none
GitHub Issue: none
Status: Complete

##### Summary

Advanced TFTP 0.8.1 provides socket-activated downloads on Rocky Linux 8.10 and 10.2.

##### Scope

Source selection, service account preparation, root-managed publication directory, download-only systemd policy, Bash checks and tests, CI, and operator procedures.

Out of scope: Production acceptance, periodic monitoring, recursive publication-policy enforcement, and concurrent-load capacity.

##### Completion Criteria

- Both supported container images build and install version 0.8.1.
- Real systemd lifecycle and installation regression suites pass.
- Separate containers download matching content and reject uploads and overwrites.

##### Dependencies And Decisions

None. Completion covers the implemented baseline; M2 owns commit preparation.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

The steps below describe delivered scope; they do not assert retrospective plan acceptance.

1. Select upstream v0.8.1 and configure the socket-activated service.
2. Provide Bash installed-state, client, lifecycle, and installation checks.
3. Document installation, operation, update, recovery, removal, and host acceptance.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Integration | Run tests/service.bash and tests/installation.bash against installed programs and real systemd. | Rocky 8.10 and 10.2 containers | 33 service assertions and 100 installation assertions pass per OS. |
| T2 | Network integration | Run bash tests/network.bash; inspect peer downloads and new-file and overwrite PUT checks. | Two separate Rocky containers | Exact downloaded bytes; PUT rejected; server files unchanged. |
| T3 | Lifecycle | Run bash tests/network.bash; inspect idle, stop/start/restart, and container restart checks. | Two separate Rocky containers | Idle server exits while socket stays active; stop prevents transfer; subsequent starts restore downloads. |
| T4 | Static | Run Bash syntax checks, ShellCheck, and git diff --check. | Repository working tree | Checks exit zero. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | 2026-10-08 to 2026-10-09 | Rocky 8.10 and 10.2 containers | Pass | Real suite stdout: 33/33 and 100/100; exit zero. Rocky 8.10 also passed the subsequent full review run. |
| T2 | 2026-10-10 | Rocky 8.10 and 10.2 peer containers | Pass | bash tests/network.bash exited zero. Both directions matched the shipped 53-byte fixture, SHA-256 dab531fb7b895fb11378bbc067ed7fbff271eb4c29d83227ea03c0652cbfbb6a; rejected PUT requests and unchanged files observed. |
| T3 | 2026-10-10 | Rocky 8.10 and 10.2 peer containers | Pass | The same script observed idle exit, stopped-peer failure, start/restart recovery, enabled and active sockets after container restart, and matching peer downloads. Final lifecycle PASS printed after cleanup. |
| T4 | 2026-10-09 | Repository working tree | Pass | Actual syntax, ShellCheck, and whitespace checks exited zero. |

##### Closure Evidence

Implemented artifacts: configure/RELEASE, configure/RULES_INSTALL, systemd templates, bin/check-service.bash, tests/*.bash, CI workflows, and operator documentation. Original suite stdout was not archived. The 2026-10-10 peer run retains commands.log, container logs, and cleanup.log in its private /tmp/atftp-network.<run_id> directory, as described in docs/VERIFICATION.md. These temporary logs are local evidence, not repository artifacts. Temporary containers and the network were removed. No production acceptance or capacity claim is included.

#### M2 - Document and prepare baseline commit

Origin: dae25fe / M2
Identity History: none
GitHub Issue: none
Status: Complete

##### Summary

Prepare a reviewable baseline commit with consistent documentation and bounded verification claims.

##### Scope

Canonical milestone record, documentation navigation, monitoring and permission boundaries, verification limits, and exact commit preparation.

Out of scope: Executing commit or push without the corresponding authorization; implementation of M3, M4, or M5.

##### Completion Criteria

- Every changed and untracked delivery file has an explicit commit scope.
- Documentation distinguishes implemented behavior from proposals.
- Commit message and staging artifacts pass their required checks.

##### Dependencies And Decisions

M1. D1 fixes the order: baseline preparation precedes next-stage implementation.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

Documentation consolidation was authorized on 2026-10-09; commit preparation and execution were authorized on 2026-10-10. These steps record delivered scope without asserting retrospective plan acceptance.

1. Record completed behavior and observed tests.
2. Update documentation links and describe the verification boundary.
3. Prepare the commit message and exact staging scope under git-workflow.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Documentation | Read links and compare statements with shipped code and observed results. | Repository | No broken links or unsupported completion claims. |
| T2 | Commit preparation | Compare staged and unstaged scope, untracked delivery files, and prepared artifacts. | Repository | All intended files are accounted for; no unrelated files included. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | 2026-10-09 | Repository | Pass | Local documentation targets exist; five work rows match five details; current behavior matches configure/RULES_INSTALL, configure/RULES_SYSTEMD, Bash checks, and observed container results. Bash syntax, ShellCheck, and git diff --check exit zero. |
| T2 | 2026-10-10 | Repository and origin/master | Pass | Prepared message and staging files passed Bash syntax, ShellCheck, explicit 36-file scope, and staged whitespace checks. Commits d1a4981, 6db0cc8, and b1f4d13 were inspected and pushed; local and upstream HEAD matched b1f4d13. |

##### Closure Evidence

Completed 2026-10-10. Version commit d1a4981, service/test commit 6db0cc8, and documentation commit b1f4d13 contain the baseline. The worktree was clean and origin/master matched after push. Preparation artifacts remain local under ignored work/.

#### M3 - Published directory policy

Origin: dae25fe / M3
Identity History: none
GitHub Issue: none
Status: Not started

##### Summary

Specify ownership and access rules for the complete published directory tree.

##### Scope

Directory layout, publisher identity, directory traversal and file read permissions, write restrictions, symlinks, ACLs, and inspection before any permission changes.

Out of scope: Applying recursive chmod/chown before policy acceptance; network-client authorization through Unix permissions.

##### Completion Criteria

- Policy names who can publish and who can read.
- Existing-file migration and recovery are defined without silently modifying content.
- Real nested-file, unreadable-file, writable-file, and link cases have test expectations.

##### Dependencies And Decisions

None. Suggested root:atftp directories 0750 and files 0640 remain proposals; current defaults are 0755 and operator-published 0644 files.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

The steps below are proposals; listing them does not authorize implementation.

1. Inventory current root and descendant permissions, including ACLs and symlinks.
2. Compare root-only publication with an explicitly authorized publisher account.
3. Present the policy, migration procedure, and tests before implementation.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Policy validation | Use actual service-user access and real TFTP reads of nested files. | Two supported Rocky containers | Approved files download; disallowed paths and permissions produce the defined result. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | Not run | Two supported Rocky containers | Pending | Policy and verification procedure are not implemented. |

##### Closure Evidence

None.

#### M4 - EPICS IOC monitoring design

Origin: dae25fe / M4
Identity History: none
GitHub Issue: none
Status: Not started

##### Summary

Design EPICS IOC monitoring based on actual TFTP UDP downloads.

##### Scope

Configurable endpoint, published probe file, expected content, interval, timeout, bounded transfer execution, status PVs, last-success time, consecutive failures, and alarm behavior.

Out of scope: Assuming a successful download proves disk capacity or internal process health; adding HTTP by default; choosing an IOC repository without review.

##### Completion Criteria

- The design specifies real TFTP downloads and content validation.
- The PV specification distinguishes success, timeout, server error, content mismatch, and stale results.
- IOC startup, shutdown, scheduling, and recovery behavior are defined.

##### Dependencies And Decisions

None. Repository placement, implementation approach, PV names, and alarm thresholds remain design choices.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

The steps below are proposals; listing them does not authorize implementation.

1. Specify the download probe and its observable results.
2. Define PVs, scheduling, stale-data behavior, and alarm recovery.
3. Select repository placement and implementation after reviewing the design.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Design review | Walk success, timeout, server error, content mismatch, stale data, shutdown, and recovery scenarios against the design. | Design document | Every scenario defines PV values, alarm behavior, scheduling, and a later real-IOC acceptance test. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | Not run | Design document | Pending | No design review completed; implementation and real-IOC integration belong to separately assigned work. |

##### Closure Evidence

None.

#### M5 - Concurrent boot capacity plan

Origin: dae25fe / M5
Identity History: none
GitHub Issue: none
Status: Not started

##### Summary

Define a measurement plan for simultaneous firmware or boot downloads.

##### Scope

Client count, approved file sizes, completion deadline, supported client options, simultaneous request launch, correctness, completion-time distribution, failures, retransmissions where observable, and server/network resource usage.

Out of scope: Executing load tests or production-device acceptance; treating MAXTHREAD as a throughput guarantee; equating Docker processes with physical-device acceptance.

##### Completion Criteria

- Required client count, file size, completion deadline, and acceptable failures are explicitly set.
- The planned procedure uses real atftp clients against the shipped server with bounded execution.
- The evidence specification includes resources, network, options, file identity, repeat count, completion times, failures, and content checks.
- The plan includes thread-limit overload, recovery, and separate production-device acceptance criteria.

##### Dependencies And Decisions

D2. Candidate load points of 50, 100, 200, and 500 clients are proposed, not an accepted capacity requirement.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

The steps below are proposals; listing them does not authorize implementation.

1. Define the operational boot requirement and measurement conditions.
2. Specify a repeatable real-client load procedure and evidence format.
3. Define how measurements will be compared against the accepted requirement.
4. Define later implementation, Docker load-test, and production acceptance work; evaluate multicast only when device and network support is established.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Plan review | Check workload, synchronization, bounded execution, file validation, and evidence definitions. | Measurement plan | Every load point has defined inputs and observable acceptance criteria. |
| T2 | Plan review | Walk overload and recovery scenarios against the proposed procedure. | Measurement plan | The procedure measures outcomes without assuming queue or retry behavior. |
| T3 | Plan review | Check the boundary between Docker results and actual-device acceptance. | Measurement plan | Later deployment tests have explicit prerequisites and completion criteria. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | Not run | Measurement plan | Pending | Workload and evidence definitions require review. |
| T2 | Not run | Measurement plan | Pending | Overload and recovery procedure requires review. |
| T3 | Not run | Measurement plan | Pending | Deployment acceptance boundary requires review; no capacity claim is made. |

##### Closure Evidence

None.

#### G1 - Representative device information and access

Origin: dae25fe / G1
Identity History: none
Status: Open

Condition: Obtain representative BLM and PSC board identities, U-Boot versions and environments, requested file paths and sizes, boot usage, device counts, timing requirements, publication ownership, and recovery procedures.

Responsible party: Device owners and operations staff.
Affected work: M6. Device-specific inputs also inform M3 and M5 without preventing their generic preparation.
Completion criterion: Required information is recorded and representative devices are available for acceptance tests.
Observed result: Not received.
Closure evidence: None.

#### M6 - U-Boot device acceptance

Origin: dae25fe / M6
Identity History: none
GitHub Issue: none
Status: Blocked

##### Summary

Verify download-only TFTP service with representative control devices running U-Boot.

##### Scope

Device-specific request paths, complete boot file sets, transfer options, content validation, boot, and previous-image recovery.

Out of scope: Treating atftp client tests or container results as actual-device acceptance; production concurrent-load execution.

##### Completion Criteria

- Record the board and U-Boot build for each tested device family.
- Observe complete image downloads and successful boot using the deployed file paths.
- Observe previous-image recovery and record transfer options and completion times against agreed criteria.

##### Dependencies And Decisions

G1; resume as Not started. Record requested work on 2026-10-10; device information and access remain external prerequisites.

##### Implementation Plan

Plan Status: draft
Plan Acceptance: none
Implementation Authorization: none
Superseded Plan Artifacts: none

1. Review device information and agree on device-specific acceptance criteria.
2. Test actual downloads, boot, and previous-image recovery on representative devices.
3. Record observed results and any remaining compatibility limits.

##### Test Plan

| Label | Layer | Method | Environment | Expected Result |
| --- | --- | --- | --- | --- |
| T1 | Device acceptance | Download complete images, validate content where supported, boot, and recover the previous image. | Representative BLM and PSC devices | Paths, content, boot, recovery, and timing meet agreed criteria. |

##### Verification Results

| Label | Observed At | Environment | Result | Evidence |
| --- | --- | --- | --- | --- |
| T1 | Not run | Representative BLM and PSC devices | Pending | Device information and access are required. |

##### Closure Evidence

None.

## Backlog

### Work

| ID | Work unit | Type | Status | Ready | Deps | Done when / Evidence |
| --- | --- | --- | --- | --- | --- | --- |

### Backlog Details

No unassigned work.
