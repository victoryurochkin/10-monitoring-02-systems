# Запуск TICK-стека

Практическая часть выполнялась на собственном сервере Debian 12.

## Состав стенда

- InfluxDB
- Telegraf
- Chronograf
- Kapacitor
- Docker
- Docker Compose

## Быстрый запуск

Из корня репозитория:

```bash
chmod +x scripts/run-tick-stack.sh
./scripts/run-tick-stack.sh
```

## Проверка

```bash
chmod +x scripts/check-metrics.sh
./scripts/check-metrics.sh
```

## Chronograf

После запуска Chronograf доступен по адресу:

```text
http://<SERVER_IP>:8888
```

В выполненной работе сервер имел IP:

```text
192.168.1.87
```

## Проверка measurements

```bash
docker exec -it sandbox_influxdb_1 influx -database telegraf -execute 'SHOW MEASUREMENTS'
```

Ожидаемые Docker-метрики:

```text
docker
docker_container_blkio
docker_container_cpu
docker_container_mem
docker_container_net
docker_container_status
```

## Важно

Команда:

```bash
chmod 666 /var/run/docker.sock
```

использована только для учебного стенда, чтобы Telegraf мог читать Docker API и собирать Docker-метрики.

После завершения работы стенда права на Docker socket можно вернуть обратно:

```bash
chmod 660 /var/run/docker.sock
```
