#!/usr/bin/env bash
# SSH-only host firewall, ufw (Ubuntu/Debian).
# ufw already allows loopback, established and ping; we add rate-limited SSH and deny the rest.
#
#   SSH_PORT=22   ALLOW_FROM=""  CIDR (v4 or v6); empty = anywhere
set -euo pipefail
SSH_PORT="${SSH_PORT:-22}" ALLOW_FROM="${ALLOW_FROM:-}"
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

ufw --force reset >/dev/null           # wipes rules and disables; re-enabled at the end
ufw default deny incoming
ufw default allow outgoing

# "limit" = allow, but drop a source after 6 new connections in 30 s.
if [[ -n "$ALLOW_FROM" ]]; then
  ufw limit proto tcp from "$ALLOW_FROM" to any port "$SSH_PORT"
else
  ufw limit "$SSH_PORT/tcp"
fi

ufw --force enable                      # ufw persists on its own
ufw status verbose
