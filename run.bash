#!/bin/bash

nameservers_add="127.0.0.1,8.8.8.8"
net_int_public="$(ip a | grep -Poi '2: \K[[:alnum:]]+')"
net_int_private="$(ip a | grep -Poi '3: \K[[:alnum:]]+')"

ip_add="192.168.4.254"
ip_mask="24"

domain_name="prof.pdl"
start_ip="1"
end_ip="20"

if [ "$1" != "-u" ]; then
	# NETPLAN
	echo "NETPLAN CONFIG"
	read -p "IP da rede privada (192.168.4.254): " ip_add_r
	read -p "Comprimento de mask (24): " ip_mask_r

	if [ "$ip_add_r" != "" ]; then
		ip_add="$ip_add_r"
	fi
	if [ "$ip_mask_r" != "" ]; then
		ip_mask="$ip_mask_r"
	fi

	# DHCP Server (isc-dhcp-server)
	echo "DHCP Server"
	read -p "Domain Name (prof.pdl): " domain_name_r
	read -p "Start Ip (1): " start_ip_r
	read -p "End Ip (20): " end_ip_r

	if [ "$domain_name_r" != "" ]; then
		domain_name="$domain_name_r"
	fi
	if [ "$start_ip_r" != "" ]; then
		start_ip="$start_ip_r"
	fi
	if [ "$end_ip_r" != "" ]; then
		end_ip="$end_ip_r"
	fi
fi

# Update
apt update

### NETPLAN ###
ip_3="$(echo -e ${ip_add} | grep -Poi '[[:digit:]]+.[[:digit:]]+.[[:digit:]]+')"
ip_s1=${ip_add%%.*}
ip_last3=${ip_add#*.}
ip_s2=${ip_last3%%.*}
ip_last2=${ip_last3#*.}
ip_s3=${ip_last2%.*}
ip_s4=${ip_last2#*.}

cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bk

netplan_config="network:
  ethernets:
    ${net_int_public}:
      dhcp4: true
    ${net_int_private}:
      dhcp4: false
      addresses: [${ip_add}/${ip_mask}]
      nameservers:
        addresses: [${nameservers_add}]
      dhcp6: false
  version: 2"
echo -e "${netplan_config}" > "/etc/netplan/00-installer-config.yaml"

### IPv4 Forwarding ###
sed -i '/net.ipv4.ip_forward=/s/^#//g' "/etc/sysctl.conf"
sysctl -p

### Iptables ###
apt install iptables-persistent -y
iptables -t nat -A POSTROUTING -o ${net_int_public} -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

### DHCP Server (isc-dhcp-server) ###
apt install isc-dhcp-server -y
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bk

dhcp_config="option domain-name \"${domain_name}\";
option domain-name-servers ${ip_add}, 8.8.8.8;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

authoritative;

subnet ${ip_3}.0 netmask 255.255.255.0 {
	option routers ${ip_add};
	option subnet-mask 255.255.255.0;
	range dynamic-bootp ${ip_3}.${start_ip} ${ip_3}.${end_ip};
}
"
echo -e "$dhcp_config" > /etc/dhcp/dhcpd.conf
systemctl restart isc-dhcp-server

### DNS Server ###
apt install bind9 bind9utils dnsutils -y
echo 'include "/etc/bind/named.conf.internal-zones";' >> "/etc/bind/named.conf"

### DNS Internal Zone ###
internal_zone_config="zone \"${domain_name}\" IN {
	type master;
	file \"/etc/bind/${domain_name}.lan\";
	allow-update { none; };
};

zone \"${ip_s3}.${ip_s2}.${ip_s1}.in-addr.arpa\" IN {
	type master;
	file \"/etc/bind/${ip_s3}.${ip_s2}.${ip_s1}.db\";
	allow-update { none; };
};"

echo -e "$internal_zone_config" > "/etc/bind/named.conf.internal-zones"


### Bind Options ###
bind_options="acl internal-network {
${ip_3}.0/24;
127.0.0.0/8;
};

options {
	directory \"/var/cache/bind\";

	dnssec-validation auto;

	listen-on-v6 { any; };


	allow-query { localhost; internal-network; };

	allow-transfer { localhost; };

	recursion yes;
};
"
echo -e "$bind_options" > "/etc/bind/named.conf.options"

### DNS ZONE ###
dns_zone="\$TTL 86400
@	IN	SOA	server.${domain_name}. root.${domain_name}. (
	20210420	;Serial
        3600		;Refresh
        1800		;Retry
        604800		;Expire
        86400		;Minimum TTL
)

	IN	NS	server.${domain_name}.
	IN	A	${ip_add}
	IN	MX 10	server.${domain_name}.

server	IN	A	${ip_add}
www	IN	A	${ip_3}.221


ftp	IN	CNAME	server.${domain_name}.
mail	IN	CNAME	server.${domain_name}.
"

echo -e "$dns_zone" > "/etc/bind/${domain_name}.lan"

### DNS REVERSE ZONE ###
dns_reverse_zone="\$TTL 86400
@	IN	SOA	server.${domain_name}. root.${domain_name}. (
		20210420	;Serial
		3600		;Refresh
		1800		;Retry
		604800		;Expire
		86400		;Minimum TTL
)

	IN	NS	server.${domain_name}.

220	IN	PTR	server.${domain_name}.
221	IN	PTR	www.${domain_name}.
"
echo -e "$dns_reverse_zone" > "/etc/bind/${ip_s3}.${ip_s2}.${ip_s1}.db"

systemctl restart named
netplan apply

###############
systemctl restart named
netplan apply
systemctl restart isc-dhcp-server

clear
dhcp_status="$(systemctl status isc-dhcp-server | grep -Poi 'Active: \K[[:graph:]]+')"
dns_status="$(systemctl status named | grep -Poi 'Active: \K[[:graph:]]+')"

echo -e "DHCP SERVICE : $dhcp_status"
echo -e "DNS  SERVICE : $dns_status"

dns_test_1="$(dig ${domain_name} | grep -Poi 'ANSWER: \K[[:graph:]]')"
dns_test_2="$(nslookup ${ip_add} | grep -Poi 'name = \K[[:graph:]]+')"

if [ "$dns_test_1" = "1" ]; then
	echo "DNS LOOKUP: GOOD"
else
	echo "DNS LOOKUP: BAD"
fi
if [ "$dns_test_2" = "" ]; then
	echo "DNS REVERSE LOOKUP: BAD"
else
	echo "DNS LOOKUP: GOOD"
fi
