# VPN Stack

This stack routes qBittorrent traffic through Gluetun to ensure all torrent
traffic is VPN-protected.

## Architecture
qBittorrent shares the network namespace of Gluetun (`network_mode: service:gluetun`),
ensuring no traffic leaves the host without the VPN tunnel.
