#!/usr/bin/env bash
# Per-boot startup for the SanoVault web development environment.
# Brings up the local Neon-compatible Postgres stack and applies migrations.
set -euo pipefail

CURSOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(cd "$CURSOR_DIR/../.." && pwd)/sanovault-web"

if ! grep -q "db.localtest.me" /etc/hosts; then
  echo "127.0.0.1 db.localtest.me api.localtest.me auth.localtest.me" | sudo tee -a /etc/hosts >/dev/null
fi

"$CURSOR_DIR/dockerd-up.sh"
sudo docker compose -f "$CURSOR_DIR/docker-compose.yml" up -d

# Wait for the Neon proxy (Caddy front on 4444) to accept requests.
for _ in $(seq 1 30); do
  if curl -s -o /dev/null -X POST http://127.0.0.1:4444/sql; then
    break
  fi
  sleep 2
done

# Forward loopback :443 to the proxy's internal HTTPS listener so the Neon
# serverless driver works with its default endpoints and no code changes.
if ! sudo ss -tln 2>/dev/null | grep -q ':443 '; then
  sudo nohup socat TCP-LISTEN:443,fork,reuseaddr TCP:127.0.0.1:4445 >/tmp/socat443.log 2>&1 &
fi

cd "$WEB_DIR"
NODE_EXTRA_CA_CERTS="$CURSOR_DIR/neon-server.pem" npm run db:migrate
