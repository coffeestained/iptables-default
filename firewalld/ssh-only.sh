#!/usr/bin/env bash
# SSH-only host firewall, firewalld (RHEL/Fedora/openSUSE).
# Creates a zone "ssh-only" (target DROP, ping + SSH allowed), binds every interface to it,
# makes it the default. Established connections are accepted by firewalld's own base rules.
#
#   SSH_PORT=22   ALLOW_FROM=""  CIDR (v4 or v6); empty = anywhere
set -euo pipefail
SSH_PORT="${SSH_PORT:-22}" ALLOW_FROM="${ALLOW_FROM:-}"
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
Z=ssh-only
fw() { firewall-cmd -q --permanent "$@"; }

fw --delete-zone="$Z" 2>/dev/null || true
fw --new-zone="$Z"
fw --zone="$Z" --set-target=DROP
fw --zone="$Z" --add-protocol=icmp
fw --zone="$Z" --add-protocol=ipv6-icmp        # neighbour discovery; never drop this

# Rich rules give us the rate limit (6/min; firewalld limits globally, not per source).
if [[ -n "$ALLOW_FROM" ]]; then
  fam=ipv4; [[ "$ALLOW_FROM" == *:* ]] && fam=ipv6
  fw --zone="$Z" --add-rich-rule="rule family=$fam source address=$ALLOW_FROM port port=$SSH_PORT protocol=tcp limit value=6/m accept"
else
  fw --zone="$Z" --add-rich-rule="rule port port=$SSH_PORT protocol=tcp limit value=6/m accept"
fi

# NetworkManager pins interfaces to zones; move them all so "public" can't leak ports.
for i in /sys/class/net/*; do
  i=${i##*/}; [[ "$i" == lo ]] && continue
  fw --zone="$Z" --change-interface="$i"
done

firewall-cmd -q --set-default-zone="$Z"
firewall-cmd -q --reload                     # permanent config is already persisted
firewall-cmd --zone="$Z" --list-all
