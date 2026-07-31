# Metrics

TrueNAS disk/pool monitoring with Prometheus + Grafana. TrueNAS SCALE's built-in
Graphite exporter (Netdata) pushes metrics to a bridge container
([truenas-graphite-to-prometheus](https://github.com/Supporterino/truenas-graphite-to-prometheus))
which translates them for Prometheus. Nothing is installed on TrueNAS itself.

```
TrueNAS (Netdata) --graphite push--> graphite_exporter --scrape--> Prometheus --> Grafana
```

## Exposed Ports
- 9109/tcp – graphite_exporter: TrueNAS pushes Graphite-formatted metrics here (unauthenticated — LAN only, never port-forward)
- 9108/tcp – graphite_exporter: translated Prometheus metrics
- 9090/tcp – Prometheus web UI
- 3000/tcp – Grafana web UI

## Volumes
- `prometheus_data` (named volume) – Prometheus TSDB, 90d retention
- `grafana_data` (named volume) – Grafana dashboards/settings
- `./prometheus/prometheus.yml` – scrape config (already points at `graphite_exporter:9108`)
- `./grafana/provisioning` – auto-provisions the Prometheus data source in Grafana

Named volumes are used for data (instead of `${CONTAINER_ROOT}` bind mounts) because
Prometheus and Grafana run as non-root UIDs (65534 / 472) and would need chowned host dirs.

## Setup

1. `cp .env.example .env` and set a real Grafana admin password.
2. `docker compose up -d`
3. Configure TrueNAS to push metrics — in the TrueNAS SCALE UI:
   **Reporting → Exporters → Add**
   - Name: `prometheus`
   - Type: `GRAPHITE`
   - Destination IP: this server's IP
   - Port: `9109`
   - Prefix: `truenas` (must match exactly — the mapping file expects it)
   - Hostname: a name for the TrueNAS box (becomes the `instance` label in Prometheus)
   - Update Every: `30` (matches the scrape interval in `prometheus.yml`)
   - Send Names Instead Of Ids: leave default (`true`)
   - Check **Enable**, then Save.

## Verify

```bash
curl -s http://localhost:9108/metrics | grep truenas
```

`truenas_*` metrics should appear within a minute (after TrueNAS's next push cycle).
Then check `http://<this-server-ip>:9090/targets` — the `truenas` job should be UP.

## Dashboards

Grafana is at `http://<this-server-ip>:3000` with the Prometheus data source and a
**TrueNAS Disk Usage** dashboard auto-provisioned from
`grafana/provisioning/dashboards/` (pool % full, free space, capacity over time,
per-dataset growth). Edit the JSON and Grafana picks it up within 30s; adding a
new provisioning file requires `docker compose restart grafana`.

Optionally import the ready-made dashboards from the
[truenas-graphite-to-prometheus](https://github.com/Supporterino/truenas-graphite-to-prometheus)
repo (`dashboards/` folder): Dashboards → New → Import → Upload JSON file.

## Pool capacity metrics (netdata.conf fix)

Pool/dataset fill level comes from Netdata's `diskspace` plugin (per-mountpoint
charts under `/mnt/<pool>`), mapped to `disk_bytes_used` / `disk_bytes_avail`.
TrueNAS's stock Netdata config doesn't export these, so the custom `netdata.conf`
from the mapping-file repo must be installed on the TrueNAS host — plus two extra
fixes needed on older TrueNAS releases: the config's state/cache dirs
(`/var/db/system/netdata/ix_state`, `ix_cache`) don't exist and must be created,
and the stock netdata systemd unit runs with `ProtectSystem=full`, so a drop-in
(`zz-readwrite.conf` with `ReadWritePaths=/var/db/system/netdata`) is required or
netdata crash-loops with "Read-only file system".

All three steps are captured in [`truenas/fix-netdata.sh`](truenas/fix-netdata.sh) —
copy it to the TrueNAS host and run as root.

TrueNAS **wipes these customizations on every update** — rerun the script after
each upgrade.

Values are in **GiB** (see the `unit` label), not bytes. Mountpoints are
slugified and lowercased (`/mnt/Atlas2/media` -> `_mnt_atlas2_media`).

Useful queries (per-mount `used` only counts that dataset's own data, so pool %
full sums all of the pool's datasets):

```promql
# Pool free space (GiB)
disk_bytes_avail{mountpoint="_mnt_atlas2"}

# Pool % full (approximate; excludes snapshot-only space)
100 * sum(disk_bytes_used{mountpoint=~"_mnt_atlas2.*"})
  / (sum(disk_bytes_used{mountpoint=~"_mnt_atlas2.*"}) + sum(disk_bytes_avail{mountpoint="_mnt_atlas2"}))
```
