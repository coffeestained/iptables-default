#!/usr/bin/env bash
# Pick the right ssh-only config for this box and apply it.
#
#   sudo ./apply.sh                    # autodetect: ufw > firewalld > nftables > iptables
#   sudo SSH_PORT=2222 ./apply.sh      # custom port (all backends)
#   sudo ALLOW_FROM=10.0.0.0/8 ./apply.sh ufw
#
# nftables note: SSH_PORT is substituted; ALLOW_FROM needs the two-line edit in
# nftables/ssh-only.nft (the file is meant to be read, not templated).
set -euo pipefail
cd "$(dirname "$0")"

tool="${1:-}"
if [[ -z "$tool" ]]; then
  for t in ufw firewall-cmd nft iptables; do command -v "$t" >/dev/null && { tool=$t; break; }; done
  [[ -n "$tool" ]] || { echo "no firewall tool found" >&2; exit 1; }
fi
case "$tool" in firewall-cmd) tool=firewalld ;; nft) tool=nftables ;; esac

echo "ssh-only via $tool  (SSH_PORT=${SSH_PORT:-22} ALLOW_FROM=${ALLOW_FROM:-anywhere})"
case "$tool" in
  nftables)
    [[ -n "${ALLOW_FROM:-}" ]] && echo "warning: ALLOW_FROM ignored for nftables, edit the .nft file" >&2
    sed "s/^define ssh_port = .*/define ssh_port = ${SSH_PORT:-22}/" nftables/ssh-only.nft > /etc/nftables.conf
    nft -f /etc/nftables.conf
    systemctl enable --now nftables >/dev/null 2>&1 || true
    nft list ruleset
    ;;
  iptables|ufw|firewalld) bash "$tool/ssh-only.sh" ;;
  *) echo "unknown tool: $tool" >&2; exit 1 ;;
esac
