# Sync Stack

This stack runs Syncthing to synchronize Obsidian vaults and other files
between devices.

## Exposed Ports
- 8384/tcp – Web UI
- 22000/tcp/udp – Device sync
- 21027/udp – Local discovery

## Volumes
- `/config` – Syncthing configuration
- `/vaults` – Data to be synchronized
