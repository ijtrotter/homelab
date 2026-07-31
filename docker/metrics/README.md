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

Grafana is at `http://<this-server-ip>:3000` with the Prometheus data source already
provisioned. Import the ready-made dashboards from the
[truenas-graphite-to-prometheus](https://github.com/Supporterino/truenas-graphite-to-prometheus)
repo (`dashboards/` folder): Dashboards → New → Import → Upload JSON file.
Pool/disk capacity panels use the `truenas_zfs_pool_*` metrics — see `METRICS.md`
in that repo for current metric names.

## Version note

TrueNAS SCALE **25.04+** dropped some default Netdata metrics; the mapping file's
maintainer requires copying a custom `netdata.conf` to `/etc/netdata/netdata.conf`
on the TrueNAS host (reapply after every TrueNAS update — it gets overwritten).
See the repo README. On 24.04/24.10 this is not needed.
