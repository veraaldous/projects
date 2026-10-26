# WildFly Linux Administration Lab

A manual lab covering Java application deployment and Linux application-server administration.

## Environment

- RHEL-compatible Linux VM
- OpenJDK 21
- WildFly installed in `/opt/wildfly`
- Dedicated `wildfly` service account
- systemd service management
- Initial heap: 256 MiB
- Maximum heap: 512 MiB

## Repository files

| File | Purpose |
|---|---|
| `sample-app/index.jsp` | Sample application showing Java version, heap limit and server time |
| `systemd/wildfly.service` | WildFly systemd unit |
| `config/wildfly` | Java runtime and JVM options |
| `scripts/wildfly-cli` | CLI wrapper that explicitly selects Java 21 |

## Package the application

From the root of the `projects` repository:

```bash
/usr/lib/jvm/java-21-openjdk/bin/jar --create \
  --file /var/tmp/hello.war \
  -C wildfly/sample-app .
```

Deploy the WAR to `/opt/wildfly/standalone/deployments/`.

## Service and application checks

```bash
systemctl status wildfly
curl -i http://127.0.0.1:8080/hello/
sudo -u wildfly /usr/local/bin/wildfly-cli --connect \
  --command='deployment-info'
```

## Logs and ports

```bash
journalctl -u wildfly -b
tail -f /opt/wildfly/standalone/log/server.log
ss -lntp | grep -E ':8080|:9990'
```

## Observed results

- Management CLI reported server state `running`.
- `hello.war` was enabled with deployment status `OK`.
- The application returned HTTP 200.
- The JSP displayed Java 21.0.12.1 and a maximum heap of 512 MiB.

## Troubleshooting completed

The original CLI command selected Java 8 and failed with
`UnsupportedClassVersionError`. Explicitly selecting Java 21 resolved it.

The CLI wrapper makes this selection repeatable without changing the
system-wide default Java. The systemd service and manual CLI have separate
environments.

Ansible automation is planned as a later phase.

## Access from a Windows browser

The application interface listens on all IPv4 interfaces using
`-b 0.0.0.0`. The management interface remains bound to `127.0.0.1`.

From a Windows computer that can reach the VM, open:

```text
http://192.168.56.101:8080/hello/
