#!/usr/bin/env bash
# Long-lived Docker daemon for the SanoVault dev environment, run as a
# persistent terminal so it stays alive for the whole session. The nested
# Cloud Agent VM cannot use overlayfs, so /etc/docker/daemon.json pins vfs.
set -euo pipefail

sudo mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  echo '{"storage-driver":"vfs","features":{"containerd-snapshotter":false}}' | sudo tee /etc/docker/daemon.json >/dev/null
fi

if sudo docker info >/dev/null 2>&1; then
  exec sudo tail -F /tmp/dockerd.log
fi

sudo rm -f /var/run/docker.pid 2>/dev/null || true
exec sudo dockerd
