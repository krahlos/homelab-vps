# CrowdSec

## SSH log source

Ubuntu 24.04 writes `auth.log` in RFC 3339 format. CrowdSec's `syslog-logs` parser expects
RFC 3164 and silently drops non-matching lines, breaking SSH detection.

Fix: `/etc/rsyslog.d/10-crowdsec-auth.conf` writes `auth`/`authpriv` events to
`/var/log/auth-crowdsec.log` using a traditional-format template. This file is mounted
into the container and monitored instead of `auth.log`.

AppArmor blocks rsyslog from writing to new paths by default. The local override at
`/etc/apparmor.d/local/usr.sbin.rsyslogd` grants write access to the new file.
