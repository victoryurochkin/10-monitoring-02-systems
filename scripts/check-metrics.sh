#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../tick-stack"

echo "[INFO] Docker containers:"
docker-compose -p sandbox ps

echo
echo "[INFO] InfluxDB databases:"
docker exec -it sandbox_influxdb_1 influx -execute 'SHOW DATABASES'

echo
echo "[INFO] Telegraf measurements:"
docker exec -it sandbox_influxdb_1 influx -database telegraf -execute 'SHOW MEASUREMENTS'

echo
echo "[INFO] Telegraf logs:"
docker-compose -p sandbox logs --tail=50 telegraf
