#! /bin/sh
set -eu

# default hostname
echo "amnesiac-debian" > /etc/hostname

# disable systemd socket activation for sshd
echo "disable ssh.socket" >> /lib/systemd/system-preset/90-systemd.preset

# default nftables rules
cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0; policy drop;
		ct state invalid drop; ct state related,established accept;
		iifname lo accept
		ip protocol icmp limit rate 4/second accept
	        ip6 nexthdr icmpv6 icmpv6 type { echo-request, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } limit rate 4/second accept

		tcp dport 4722 accept
                counter #log prefix "Default drop INPUT: " level info
	}
	chain forward {
		type filter hook forward priority 0; policy accept;
	}
	chain output {
		type filter hook output priority 0; policy accept;
	}
}
EOF


# until we know how to make systemd-resolved add options to its /run/systemd/resolve/stub-resolv.conf
rm /etc/resolv.conf
printf "nameserver 127.0.0.1\noptions trust-ad edns0\n" > /etc/resolv.conf

# Tell unbound that we don't use resolvconf and that we don't need the
# helper to update the trust anchor. We update the trust anchor using
# unbound-anchor.
cat > /etc/default/unbound << 'EOF'
RESOLVCONF=false
ROOT_TRUST_ANCHOR_UPDATE=false
EOF

cat > /etc/default/unbound-anchor << 'EOF'
UNBOUND_ANCHOR_OPTIONS="-a /var/lib/unbound/root.key"
EOF
