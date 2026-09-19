#!/usr/bin/env bash
# Long-lived web terminal for the SanoVault dev environment. Waits for the
# Docker daemon (run-dockerd.sh terminal), brings up the local Neon-compatible
# Postgres stack, applies migrations, then runs the Next.js dev server in the
# foreground so its logs stay visible.
set -euo pipefail

CURSOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(cd "$CURSOR_DIR/../.." && pwd)/sanovault-web"

if ! grep -q "db.localtest.me" /etc/hosts; then
  echo "127.0.0.1 db.localtest.me api.localtest.me auth.localtest.me" | sudo tee -a /etc/hosts >/dev/null
fi

echo "Waiting for the Docker daemon..."
for _ in $(seq 1 90); do
  if sudo docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

sudo docker compose -f "$CURSOR_DIR/docker-compose.yml" up -d

# The Neon proxy binds TLS on :443; wait until it accepts connections.
echo "Waiting for the Neon proxy on :443..."
for _ in $(seq 1 45); do
  if sudo ss -tln 2>/dev/null | grep -q ':443 '; then
    break
  fi
  sleep 2
done

cd "$WEB_DIR"
export NODE_EXTRA_CA_CERTS="$CURSOR_DIR/neon-server.pem"
npm run db:migrate
exec npm run dev
