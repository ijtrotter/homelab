#!/bin/bash
# Restores:
#   1. The custom netdata.conf (enables the diskspace plugin -> disk_bytes_used/avail,
#      i.e. pool capacity metrics; TrueNAS's stock config omits it)
#   2. The state/cache dirs the custom config expects on the system dataset
#   3. A systemd drop-in allowing writes there (stock unit has ProtectSystem=full)
set -euo pipefail

CONF_URL="https://raw.githubusercontent.com/Supporterino/truenas-graphite-to-prometheus/main/netdata.conf"

curl -fsSL -o /etc/netdata/netdata.conf "$CONF_URL"
chown root:root /etc/netdata/netdata.conf

cat >> /etc/netdata/netdata.conf <<'EOF'

[plugin:proc:diskspace]
    space usage for all disks = yes
    inodes usage for all disks = yes
EOF

mkdir -p /var/db/system/netdata/ix_state /var/db/system/netdata/ix_cache
chown -R netdata:netdata /var/db/system/netdata

printf '[Service]\nReadWritePaths=/var/db/system/netdata\n' \
  > /etc/systemd/system/netdata.service.d/zz-readwrite.conf

systemctl daemon-reload
systemctl reset-failed netdata 2>/dev/null || true
systemctl restart netdata

sleep 3
systemctl --no-pager --lines=3 status netdata
echo "Done."
