# WildFly Linux Administration Lab

A manual lab covering WildFly installation, Java application deployment,
systemd service management, and Linux troubleshooting.

This repository documents lab experience. Ansible automation is not yet
implemented or tested.

## Confirmed environment

| Component | Value |
|---|---|
| Operating system | Red Hat Enterprise Linux 9.7 |
| WildFly | 33.0.1.Final |
| Java | OpenJDK 21 |
| Installation directory | `/opt/wildfly` |
| Application account | `wildfly` |
| Application interface | `0.0.0.0:8080` |
| Management interface | `127.0.0.1:9990` |
| Initial heap | 256 MiB |
| Maximum heap | 512 MiB |
| SELinux runtime mode | Enforcing |
| SELinux boot configuration | `SELINUX=enforcing` |
| firewalld | Active |

## Repository files

| File | Purpose |
|---|---|
| `sample-app/index.jsp` | Displays Java version, heap limit and server time |
| `systemd/wildfly.service` | systemd service definition |
| `config/wildfly` | Java runtime and JVM settings |
| `scripts/wildfly-cli` | Management wrapper selecting Java 21 |
| `evidence/` | Captured service, deployment, log and HTTP output |

## Rebuild prerequisites

The following installation steps are for a fresh RHEL-compatible VM.
Do not repeat them over an existing working WildFly installation.

Required:

- Working package repositories and Internet access.
- Root privileges for installation and service configuration.
- Network connectivity between the Windows computer and the VM.

Clone the repository as a normal user:

```bash
git clone https://github.com/veraaldous/projects.git
cd projects
```

The remaining examples assume the repository is located at
`/home/advera/projects`.

## Install Java and required tools

Run as root:

```bash
dnf install -y java-21-openjdk-devel curl tar git

/usr/lib/jvm/java-21-openjdk/bin/java -version
```

The development package includes `jar`, used to package the application.

## Create the service account

Run as root. Check whether the account already exists:

```bash
getent passwd wildfly
```

If absent, create it:

```bash
useradd --system --user-group \
  --home-dir /opt/wildfly --no-create-home \
  --shell /sbin/nologin wildfly
```

WildFly runs under this dedicated account rather than root.

## Install WildFly

Run as root on a fresh VM:

```bash
cd /var/tmp

WILDFLY_VERSION=33.0.1.Final

curl -fL \
  -o "wildfly-${WILDFLY_VERSION}.tar.gz" \
  "https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz"

tar -xzf "wildfly-${WILDFLY_VERSION}.tar.gz" -C /opt

mv "/opt/wildfly-${WILDFLY_VERSION}" /opt/wildfly

chown -R wildfly:wildfly /opt/wildfly

restorecon -RF /opt/wildfly
```

The fixed version matches the release reported by the existing lab VM.

## Install the configuration files

Run as root:

```bash
install -o root -g root -m 0644 \
  /home/advera/projects/wildfly/config/wildfly \
  /etc/sysconfig/wildfly

install -o root -g root -m 0644 \
  /home/advera/projects/wildfly/systemd/wildfly.service \
  /etc/systemd/system/wildfly.service

install -o root -g root -m 0755 \
  /home/advera/projects/wildfly/scripts/wildfly-cli \
  /usr/local/bin/wildfly-cli

restorecon -v \
  /etc/sysconfig/wildfly \
  /etc/systemd/system/wildfly.service \
  /usr/local/bin/wildfly-cli
```

The environment file selects Java 21 and configures the JVM heap.

The unit runs WildFly as `wildfly`, sets restart behaviour and an
open-file limit, and applies basic service hardening.

The startup command uses:

```text
-b 0.0.0.0 -bmanagement 127.0.0.1
```

Application traffic is accepted on the VM's IPv4 interfaces.
Management access remains local.

## Start and enable the service

Run as root:

```bash
systemctl daemon-reload

systemctl enable --now wildfly

systemctl status wildfly --no-pager -l
```

After changing an existing unit:

```bash
systemctl daemon-reload
systemctl restart wildfly
```

Enabling the service configures startup at boot. A separate reboot
validation has not yet been recorded.

## Package and deploy the application

Run as root:

```bash
/usr/lib/jvm/java-21-openjdk/bin/jar --create \
  --file /var/tmp/hello.war \
  -C /home/advera/projects/wildfly/sample-app .

install -o wildfly -g wildfly -m 0640 \
  /var/tmp/hello.war \
  /opt/wildfly/standalone/deployments/hello.war
```

The default standalone deployment scanner detects the WAR.

Check the deployment markers and management status:

```bash
ls -l /opt/wildfly/standalone/deployments/hello.war*

sudo -u wildfly /usr/local/bin/wildfly-cli --connect \
  --command='deployment-info'
```

## SELinux and firewall configuration

Confirmed on the existing VM:

```text
SELinux runtime: Enforcing
SELinux boot configuration: SELINUX=enforcing
firewalld: active
```

Firewall inspection found:

| Zone | Assignment | Relevant configuration |
|---|---|---|
| `public` | Interfaces `enp0s3` and `enp0s8` at runtime | Explicit port `8000/tcp`; no explicit `8080/tcp` entry |
| `trusted` | Source `192.168.56.0/24` | Target `ACCEPT`, present in runtime and permanent configuration |

The Windows host-only adapter uses `192.168.56.1`.
Traffic from that address matches the trusted source subnet.

Browser access therefore does not depend on a public-zone
`8080/tcp` entry. The listed public-zone port `8000/tcp` is a
different port.

The source trust applies broadly to the local lab subnet; it is
not a rule restricted to WildFly alone. This documents the observed
lab configuration rather than a production firewall baseline.

Inspect the configuration:

```bash
getenforce
grep '^SELINUX=' /etc/selinux/config

sudo firewall-cmd --get-active-zones

sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --permanent --zone=public --list-all

sudo firewall-cmd --zone=trusted --list-all
sudo firewall-cmd --permanent --zone=trusted --list-all
```

For a fresh VM without the existing trusted-source arrangement,
configure application access in the appropriate firewall zone.
For example, if the relevant interface belongs to `public`:

```bash
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload
```

This fresh-VM example opens application port 8080 in public.
It does not recreate the existing trusted-subnet configuration.
Management port 9990 remains bound to localhost.

## Test locally

```bash
curl -i http://127.0.0.1:8080/hello/
```

Confirmed response and displayed values:

```text
HTTP/1.1 200 OK
Java version: 21.0.12.1
Maximum heap: 512 MiB
```

## Test from a Windows browser

Open:

```text
http://192.168.56.101:8080/hello/
```

This address belongs to the local lab network. Replace it with
the reachable VM address when rebuilding elsewhere.

The expected page displays **Aldous WildFly Lab**, Java version,
maximum heap and server time.

The Linux VM can remain CLI-only. Direct browser access does not
require an SSH tunnel when routing, binding and firewall access
are configured appropriately.

## Service and application checks

Run administrative checks as root or through sudo:

```bash
systemctl status wildfly --no-pager -l

sudo -u wildfly /usr/local/bin/wildfly-cli --connect \
  --command=':read-attribute(name=server-state)'

sudo -u wildfly /usr/local/bin/wildfly-cli --connect \
  --command='deployment-info'

ss -lntp | grep -E ':8080|:9990'
```

## Logs

```bash
journalctl -u wildfly -b -n 100 --no-pager

tail -f /opt/wildfly/standalone/log/server.log
```

Press Ctrl+C to stop following the log.

## Observed results and evidence

Confirmed:

- Server state reported `running`.
- `hello.war` was enabled with deployment status `OK`.
- The application returned HTTP 200.
- The JSP displayed Java 21.0.12.1 and maximum heap 512 MiB.
- Direct browser access from Windows worked.
- SELinux was Enforcing and firewalld was active.

Captured evidence:

- [Capture timestamp](evidence/captured-at.txt)
- [Service status](evidence/service-status.txt)
- [Deployment status](evidence/deployment-info.txt)
- [HTTP response](evidence/http-response.txt)
- [Service journal](evidence/service-journal.txt)
- [Server log](evidence/server-log.txt)

## Java CLI troubleshooting

The original CLI command selected Java 8 and failed with
`UnsupportedClassVersionError`.

The Java 21 wrapper resolved the mismatch by explicitly setting
`JAVA_HOME` and `JAVA` before invoking `jboss-cli.sh`.

The systemd service and a manually launched CLI have separate
environments. Configuring Java for the service does not
automatically configure every shell or sudo invocation.

## JVM recovery settings

`ExitOnOutOfMemoryError` requests JVM termination on an out-of-memory
error. `Restart=on-failure` allows systemd to restart a failed service.

The combined failure path has not yet been tested. A controlled
heap-exhaustion test is planned for a separate lab instance.

A restart provides recovery but does not resolve the underlying
memory problem.

## Ansible status

Ansible implementation and validation remain pending.

Planned scope:

- Install Java and WildFly.
- Create the service account and group.
- Deploy the unit, environment file and CLI wrapper.
- Deploy the sample application.
- Enable and start the service.
- Validate the installation on a clean VM.
- Run the playbook again and check for unexpected changes.

A delivery date will be recorded after confirmation.
