#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../tick-stack"

echo "[INFO] Loading environment..."
set -a
source .env-latest
set +a

echo "[INFO] Preparing local data directories..."
mkdir -p chronograf/data kapacitor/data influxdb/data

echo "[INFO] Setting permissions for lab environment..."
chmod -R 777 chronograf/data kapacitor/data influxdb/data

echo "[INFO] Allowing Telegraf to read Docker socket for lab Docker metrics..."
chmod 666 /var/run/docker.sock

echo "[INFO] Starting TICK stack with project name sandbox..."
docker-compose -p sandbox up -d --build

echo
echo "[INFO] Containers:"
docker-compose -p sandbox ps

echo
echo "[INFO] Chronograf URL:"
echo "http://<SERVER_IP>:8888"
