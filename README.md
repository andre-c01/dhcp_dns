```mermaid
classDiagram
Server <|--|> Bridge : Interface 1
Server <|--|> Internal : Interface 2
Server : Gateway

Internal : DNS
Internal: DHCP



Internal <|--|> Client
Client : Dynamic Ip
```
# :small_red_triangle_down: Using The Script :small_red_triangle_down:

`sudo su`

`git clone https://github.com/andre-c01/3933.git`

`bash ./3933/run.bash -u`

# :small_red_triangle_down: Using The Guide :small_red_triangle_down:

## NICs Setup

Before booting your machine set the default network interface to `bridge` and a second one as `internal`

## Seting Up & Using SSH

Install sshd with `apt install ssh`

After booting the vm go to `/etc/ssh/sshd_config` and uncomment `PasswordAuthentication yes` or do `sed -i '/PasswordAuthentication/s/^#//g' /etc/ssh/sshd_config\`. Then save and get the vm ip with `ip a`.

Enable & start the service `systemctl enable sshd --now`

### Using Solar Putty

Download & open "Solar-PuTTY.exe" from the repo and add a new ssh session with your **username** and **ip**.

### Using Tabby

Download Tabby from [here](https://github.com/Eugeny/tabby/releases/download/v1.0.201/tabby-1.0.201-portable-x64.zip) and do `ssh «username»@«ip»` , enter `yes` followed by the password.

## 

**Do all of the following in this terminal, utilize the copy and paste function.**

**Do Not Write Code. Copy It !**

## Sudo

**Sudo** is used to elevate the privileges of the current user to essentially root.

`sudo «command»`

For this guide make sure to **login to root** with `sudo su`

## Update , Upgrade & Install

`apt update` : Update Repos

`apt upgrade` : Upgrade All Packages

`apt install «package»` : Install a Package

For this guide make sure to do `apt update` before trying to install any package.

## Users

`add «username»` : Add a User

`usermod -aG «groupname» «username»` : Add a User to Group

## Permissions

## Services (Systemd)

`systemctl -t service` : List With Status of All System Services

`systemctl list-unit-files -t service`

`systemctl status «servicename»` : Check Status of Service

`systemctl stop «servicename»` : Stop Service

`systemctl start «servicename»` : Start Service

`systemctl restart «servicename»` : Restart Service

`systemctl reload «servicename»` : Reload Service

## Network Config (Netplan)

Default config file: `/etc/netplan/00-installer-config.yaml`

`mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bk` : Make a backup of the config file with

Replace the config file with:

```yaml
network:
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses: [192.168.4.254/24]
      nameservers:
        addresses: [127.0.0.1,8.8.8.8]
      dhcp6: false
  version: 2
```

! Check the name of the interfaces and the ip set for the internal one.

`netplan apply` : Update & Apply Config

`ip a` : Show Network Details

## IPV4 Forward

Uncomment `net.ipv4.ip_forward=1` from `/etc/sysctl.conf`

`sysctl -p` : Load settings from `/etc/sysctl.conf`

## Iptables

`iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE` : Route all trafic through enp0s3

`apt install iptables-persistent` : Install iptables-persistent

`iptables-save > /etc/iptables/rules.v4` : Save Iptables Rules

## DHCP Server (isc-dhcp-server)

`apt install isc-dhcp-server` : Install The DHCP Server

`mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bk` : Make Backup of Config File

Config file: `/etc/dhcp/dhcpd.conf`

```shell
option domain-name "prof.pdl";
option domain-name-servers 192.168.4.254, 8.8.8.8;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

authoritative;

subnet 192.168.4.0 netmask 255.255.255.0 {
    option routers 192.168.4.254;
    option subnet-mask 255.255.255.0;
    range dynamic-bootp 192.168.4.1 192.168.4.20;
}
```

! Change IPs , domain name and the range of IPs to be used.

`systemctl restart isc-dhcp-server ` 

`systemctl status isc-dhcp-server`

## DNS Server (BIND)

`apt install bind9 bind9utils`

`/etc/bind/named.conf` : Config BIND (Internal Network)

`include "/etc/bind/named.conf.internal-zones";`

### Internal Network Config

Config file: `/etc/bind/named.conf.internal-zones`

```shell
zone "prof.pdl" IN {
    type master;
    file "/etc/bind/prof.pdl.lan";
    allow-update { none; };
};

zone "4.168.192.in-addr.arpa" IN {
    type master;
    file "/etc/bind/4.168.192.db";
    allow-update { none; };
};
```

! Change IPs & domain name (leave the `.lan` at the end).

### Bind Options

Config file: `/etc/bind/named.conf.options`

```shell
acl internal-network {
192.168.4.0/24;
127.0.0.0/8;
};

options {
    directory "/var/cache/bind";

    dnssec-validation auto;

    listen-on-v6 { any; };

    allow-query { localhost; internal-network; };

    allow-transfer { localhost; };

    recursion yes;
};
```

! Change IPs.

### DNS Zones (Zone prof.pdl)

Config File: `/etc/bind/prof.pdl.lan`

```shell
$TTL 86400
@       IN      SOA     server.prof.pdl. root.prof.pdl. (
        20210420        ;Serial
        3600            ;Refresh
        1800            ;Retry
        604800          ;Expire
        86400           ;Minimum TTL
)

        IN      NS      server.prof.pdl.
        IN      A       192.168.4.254
        IN      MX 10   server.prof.pdl.

server  IN      A       192.168.4.254
www     IN      A       192.168.4.221

ftp     IN      CNAME   server.prof.pdl.
mail    IN      CNAME   server.prof.pdl.

```

! Change IPs & domain name. Pay attention to the name of the file, it must be your domain name followed by `.lan`.

### DNS REVERSE Zone prof.pdl

Config File: `/etc/bind/4.168.192.db`

```shell
$TTL 86400
@       IN      SOA     serverprof.pdl. root.prof.pdl. (
                20210420        ;Serial
                3600            ;Refresh
                1800            ;Retry
                604800          ;Expire
                86400           ;Minimum TTL
)

        IN      NS      server.prof.pdl.

220     IN      PTR     server.prof.pdl.
221     IN      PTR     www.prof.pdl.
```

! Change the domain name. Pay attention to the name of the file, it must be the 3 first segments of your IP in reverse followed by `.db`.

`systemctl restart named`

`netplan apply`

---

`dig server.prof.pdl`

`nslookup server.prof.pdl`
