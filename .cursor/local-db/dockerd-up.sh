#!/usr/bin/env bash
# Start the Docker daemon if it is not already running, detached into its own
# session so it survives after the calling start script returns. The nested
# Cloud Agent VM cannot use the overlay storage driver, so
# /etc/docker/daemon.json pins vfs.
set -euo pipefail

if sudo docker info >/dev/null 2>&1; then
  exit 0
fi

sudo rm -f /var/run/docker.pid 2>/dev/null || true
sudo bash -c 'setsid dockerd >/tmp/dockerd.log 2>&1 </dev/null &'

for _ in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done

echo "dockerd failed to start" >&2
tail -n 20 /tmp/dockerd.log >&2 || true
exit 1
