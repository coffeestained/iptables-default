#!/usr/bin/env bash
# SSH-only host firewall, iptables + ip6tables.
# In:  loopback, established, ping, SSH (rate limited). Everything else dropped.
# Out: open.
#
#   SSH_PORT=22            ALLOW_FROM=""  v4 CIDR; empty = anywhere
#   PING=yes               ALLOW_FROM6="" v6 CIDR; if ALLOW_FROM is set and this
#                                         is empty, v6 SSH stays closed
set -euo pipefail
SSH_PORT="${SSH_PORT:-22}" PING="${PING:-yes}"
ALLOW_FROM="${ALLOW_FROM:-}" ALLOW_FROM6="${ALLOW_FROM6:-}"
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

# $1 iptables|ip6tables  $2 icmp protocol name  $3 source CIDR or ""  $4 open ssh? yes|no
apply() {
  local ipt=$1 icmp=$2 cidr=$3 open=$4 src=()
  [[ -n "$cidr" ]] && src=(-s "$cidr")

  # Open policies before flushing: if a rule below errors out we are not locked out.
  $ipt -P INPUT ACCEPT; $ipt -P FORWARD ACCEPT; $ipt -P OUTPUT ACCEPT
  $ipt -F; $ipt -X

  $ipt -A INPUT -i lo -j ACCEPT
  $ipt -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  $ipt -A INPUT -m conntrack --ctstate INVALID -j DROP
  # ICMPv6 is not optional: neighbour discovery lives there.
  [[ "$PING" == yes || "$ipt" == ip6tables ]] && $ipt -A INPUT -p "$icmp" -j ACCEPT

  if [[ "$open" == yes ]]; then
    # >5 new connections / minute from one address -> drop (brute-force damping).
    $ipt -A INPUT -p tcp "${src[@]}" --dport "$SSH_PORT" -m conntrack --ctstate NEW -m recent --name ssh --set
    $ipt -A INPUT -p tcp "${src[@]}" --dport "$SSH_PORT" -m conntrack --ctstate NEW -m recent --name ssh --update --seconds 60 --hitcount 6 -j DROP
    $ipt -A INPUT -p tcp "${src[@]}" --dport "$SSH_PORT" -m conntrack --ctstate NEW -j ACCEPT
  fi

  $ipt -P INPUT DROP; $ipt -P FORWARD DROP
}

apply iptables  icmp      "$ALLOW_FROM"  yes
v6open=yes; [[ -n "$ALLOW_FROM" && -z "$ALLOW_FROM6" ]] && v6open=no
apply ip6tables ipv6-icmp "$ALLOW_FROM6" "$v6open"

# Persist with whatever this distro uses.
if command -v netfilter-persistent >/dev/null; then
  netfilter-persistent save
elif [[ -d /etc/iptables ]]; then
  iptables-save > /etc/iptables/rules.v4; ip6tables-save > /etc/iptables/rules.v6
elif command -v service >/dev/null && [[ -f /etc/sysconfig/iptables ]]; then
  service iptables save; service ip6tables save
else
  echo "rules active but NOT persisted: apt install iptables-persistent | dnf install iptables-services" >&2
fi
echo "ssh-only applied (port $SSH_PORT, from ${ALLOW_FROM:-anywhere})"
