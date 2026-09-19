#!/usr/bin/env bash
# One-time bootstrap for the SanoVault web development environment.
# Installs system packages and Node dependencies. The Docker daemon and the
# database stack are started per-boot by the terminals, not here.
set -euo pipefail

CURSOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(cd "$CURSOR_DIR/../.." && pwd)/sanovault-web"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq docker.io docker-compose-v2

# The nested VM cannot use overlayfs; pin the vfs storage driver.
sudo mkdir -p /etc/docker
echo '{"storage-driver":"vfs","features":{"containerd-snapshotter":false}}' | sudo tee /etc/docker/daemon.json >/dev/null

# The Neon serverless driver rewrites the connection host's first label to
# "api" for its HTTP endpoint, so both aliases must resolve to loopback.
if ! grep -q "db.localtest.me" /etc/hosts; then
  echo "127.0.0.1 db.localtest.me api.localtest.me auth.localtest.me" | sudo tee -a /etc/hosts >/dev/null
fi

cd "$WEB_DIR"
npm ci

# Gitignored local configuration. Real Neon Auth is unreachable locally, so
# placeholder values keep module initialization working while the public
# landing page and database-backed routes run against the local Postgres.
if [ ! -f "$WEB_DIR/.env.local" ]; then
  COOKIE="$(openssl rand -base64 32)"
  cat > "$WEB_DIR/.env.local" <<EOF
DATABASE_URL=postgresql://postgres:postgres@db.localtest.me/main?sslmode=require
DIRECT_URL=postgresql://postgres:postgres@db.localtest.me/main?sslmode=require
NEON_AUTH_BASE_URL=https://auth.localtest.me/neondb/auth
NEON_AUTH_COOKIE_SECRET=$COOKIE
NEXT_PUBLIC_APP_URL=http://localhost:3001
EOF
fi
