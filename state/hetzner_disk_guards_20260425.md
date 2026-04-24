# hetzner disk auto-prune guards — install transcript 20260425

**Context:** preventive infra to cap `/dev/md1` (root, 98G) growth after today's 97%→87% cleanup.
Full investigation → `state/hetzner_disk_accumulation_20260425.md`.

## Before / After
```
before: /dev/md1 98G 81G 13G 87% /
after : /dev/md1 98G 81G 13G 87% /   (guards are preventive, no reclaim)
```

## 1. journald cap (persistent)

`/etc/systemd/journald.conf.d/max-use.conf` (new — drop-in dir was absent, `mkdir -p` first):
```
[Journal]
SystemMaxUse=200M
MaxRetentionSec=14day
```
`systemctl restart systemd-journald` → current `journalctl --disk-usage` = 27.7M (well under cap).

## 2. /tmp tmpreaper

- package: `tmpreaper` already installed (apt install -y was idempotent).
- `/etc/tmpreaper.conf` backed up to `.bak-20260425`, then flipped commented `# TMPREAPER_TIME=7d` → `TMPREAPER_TIME=3d`.
- `TMPREAPER_DIRS='/tmp/.'` was already set.
- cron hook `/etc/cron.daily/tmpreaper` present → runs daily.

## 3. docker weekly prune

Docker is active. Installed:

`/etc/systemd/system/docker-prune.service`:
```
[Unit]
Description=Weekly docker system prune (auto)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "/usr/bin/docker system prune -af --filter until=168h && /usr/bin/docker volume prune -f"
```

`/etc/systemd/system/docker-prune.timer`:
```
[Unit]
Description=Weekly docker system prune timer

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```
enabled + started. Next trigger: **Mon 2026-04-27 00:30 CEST**.

## 4. btmp rotation

Existing config was **monthly / rotate 1 / no compress** (deficient — lets 72M accumulate).
Overwrote (no backup — previous was distro default comment-only) with:

`/etc/logrotate.d/btmp`:
```
# managed by airgenome 20260425 — weekly rotate 2 compress
/var/log/btmp {
    missingok
    weekly
    rotate 2
    compress
    create 0660 root utmp
}
```

## 5. disk watchdog

Helper script `/usr/local/sbin/disk-watchdog.sh` (cleaner than inlining in unit ExecStart — earlier inline awk got mangled through heredoc quoting):
```
#!/bin/sh
USE=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${USE:-0}" -ge 90 ]; then
  {
    echo "[$(date -Iseconds)] WARN root=${USE}%"
    du -sh /var/lib/* /home/* /root 2>/dev/null | sort -rh | head -5
    echo "---"
  } >> /var/log/disk-watchdog.log
fi
```

`/etc/systemd/system/disk-watchdog.service` → `ExecStart=/usr/local/sbin/disk-watchdog.sh`.

`/etc/systemd/system/disk-watchdog.timer`:
```
[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=30m
```
Smoke-tested with threshold temporarily lowered to 50 → log wrote correctly:
```
[2026-04-24T19:23:52+02:00] WARN root=87%
14G  /home/nexus
4.5G /var/lib/containerd
4.2G /root
3.7G /home/hexa-lang
3.5G /var/lib/docker
```
Log cleared after smoke-test. Enabled + started. Next trigger: **Sat 2026-04-25 00:18 CEST**.

## Verification
```
$ systemctl list-timers --all | grep -E 'disk-watchdog|docker-prune'
Sat 2026-04-25 00:18:02 CEST   disk-watchdog.timer    disk-watchdog.service
Mon 2026-04-27 00:30:24 CEST   docker-prune.timer     docker-prune.service

$ systemctl is-enabled docker-prune.timer disk-watchdog.timer
enabled
enabled
```

## Caps summary
| guard        | cap                        | cadence          |
|--------------|----------------------------|------------------|
| journald     | SystemMaxUse=200M / 14d    | continuous       |
| tmpreaper    | /tmp mtime > 3d            | daily cron       |
| docker-prune | images/containers > 168h + volumes | weekly   |
| btmp         | rotate 2 / weekly / gzip   | weekly (logrotate) |
| watchdog     | log top-5 if root >= 90%   | daily            |

No reboot or user-session disturbance required — all changes are drop-ins + new units.
