# ssh-only-configurations

Lock a Linux host down to SSH only. Same policy, four backends: iptables, nftables, ufw, firewalld.

Inbound: loopback, established, ping, SSH (rate limited). Everything else dropped. Outbound open. IPv6 handled. Persisted.

## Runbook

```bash
git clone https://github.com/coffeestained/ssh-only-configurations && cd ssh-only-configurations

# keep a second SSH session open until you've confirmed the new one works
sudo ./apply.sh                                  # autodetect: ufw > firewalld > nftables > iptables
sudo SSH_PORT=2222 ./apply.sh iptables           # custom port, explicit backend
sudo ALLOW_FROM=203.0.113.0/24 ./apply.sh ufw    # SSH only from your office / VPN

# verify from another machine: 22 open, everything else filtered
nc -zvw3 <host> 22; nc -zvw3 <host> 80

# undo
sudo ufw --force reset                                      # ufw
sudo firewall-cmd --set-default-zone=public                 # firewalld
sudo nft flush ruleset                                      # nftables
sudo iptables -P INPUT ACCEPT; sudo iptables -F             # iptables (+ ip6tables)
```

## Files

| path | |
|---|---|
| `apply.sh` | picks a backend, applies, persists |
| `iptables/ssh-only.sh` | `-m recent` rate limit, `iptables-persistent` / `iptables-services` save |
| `nftables/ssh-only.nft` | one `inet` table, per-source dynamic sets; becomes `/etc/nftables.conf` |
| `ufw/ssh-only.sh` | `ufw limit` |
| `firewalld/ssh-only.sh` | dedicated `ssh-only` zone, all interfaces moved into it |

Need more than SSH open? See [linux-firewall-recipes](https://github.com/coffeestained/linux-firewall-recipes).

MIT © Matthew Grady
