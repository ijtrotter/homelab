# Core Docker Services

This stack provides foundational Docker utilities used across the homelab.

## Services

### deunhealth
Monitors Docker container health status and prevents unhealthy containers
from remaining in a running state.

- Runs without network access for isolation
- Uses the Docker socket (read-only)
- Health endpoint bound to localhost only

### watchtower
Handles automated container image updates.

- Scheduled daily updates (4am)
- Removes old images after update
- Used selectively for low-risk services
