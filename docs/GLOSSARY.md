# Terms and abbreviations

These terms describe the service, verification interfaces, and planned monitoring work.

| Term | Meaning |
| --- | --- |
| ACL | Access control list: additional filesystem access rules beyond owner, group, and mode bits. |
| CI | Continuous integration: automated build and verification jobs. |
| EPICS | Experimental Physics and Industrial Control System. |
| GID | Group ID: the numeric identity of a Unix group. |
| Host acceptance | Verification on the intended deployment host and client network before operational admission. |
| HTTP | Hypertext Transfer Protocol; this repository supplies no HTTP status API. |
| IOC | Input/Output Controller in EPICS; a monitoring IOC is proposed work. |
| Published root | The directory configured by `TFTPD_DIR` from which the server serves files. |
| PV | Process variable exposed by an EPICS control system. |
| Socket activation | systemd holds a listening socket and starts the associated service when a request arrives. |
| TFTP | Trivial File Transfer Protocol, used here for file downloads. |
| Transfer port | A server-selected UDP port used for a TFTP transfer after the initial request. |
| UDP | User Datagram Protocol, the transport used by TFTP. |
| UID | User ID: the numeric identity of a Unix user. |
