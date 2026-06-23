# Домашнее задание к занятию «13. Системы мониторинга» - Юрочкин В.А.

## Описание

Данное домашнее задание посвящено базовым принципам мониторинга, различию технических и бизнес-метрик, моделям сбора метрик `pull` и `push`, а также практическому запуску TICK-стека на собственном сервере с использованием Docker и Docker Compose.

Практическая часть выполнялась на собственном сервере:

<img width="3071" height="1427" alt="image" src="https://github.com/user-attachments/assets/7b2d84fb-0dba-40b5-8020-ea58b573611f" />

- ОС: Debian GNU/Linux 12 (bookworm)
- Hostname: `tick`
- Kernel: `6.1.0-49-amd64`
- Docker: `20.10.24`
- Docker Compose: `1.29.2`
- IP-адрес сервера: `192.168.1.87`
- Репозиторий: `https://github.com/influxdata/sandbox`

<img width="1852" height="1058" alt="image" src="https://github.com/user-attachments/assets/2ea98b3f-9f84-4eec-b41b-5dc00192e291" />

<img width="2556" height="1047" alt="image" src="https://github.com/user-attachments/assets/b0339c19-49fc-4280-a342-accd8abc2184" />

---

## Содержание

1. [Минимальный набор метрик для проекта](#1-минимальный-набор-метрик-для-проекта)
2. [Метрики для менеджера продукта](#2-метрики-для-менеджера-продукта)
3. [Решение без системы сбора логов](#3-решение-без-системы-сбора-логов)
4. [Ошибка в расчёте SLA](#4-ошибка-в-расчёте-sla)
5. [Плюсы и минусы pull и push мониторинга](#5-плюсы-и-минусы-pull-и-push-мониторинга)
6. [Классификация систем мониторинга](#6-классификация-систем-мониторинга)
7. [Практическая часть: запуск TICK-стека](#7-практическая-часть-запуск-tick-стека)
8. [Настройка Docker-метрик в Telegraf](#8-настройка-docker-метрик-в-telegraf)
9. [Результаты проверки](#9-результаты-проверки)
10. [Скриншоты](#10-скриншоты)
11. [Вывод](#11-вывод)

---

## 1. Минимальный набор метрик для проекта

По условию проекта:

- платформа выполняет вычисления;
- результатом являются текстовые отчёты;
- отчёты сохраняются на диск;
- взаимодействие с платформой происходит по HTTP;
- вычисления создают нагрузку на CPU.

Минимальный набор метрик должен покрывать доступность сервиса, качество HTTP-ответов, производительность вычислений и состояние системных ресурсов.

| Метрика | Зачем нужна |
|---|---|
| Доступность HTTP-сервиса | Позволяет понять, отвечает ли приложение клиентам |
| Количество HTTP-запросов | Показывает фактическую нагрузку на сервис |
| HTTP-коды ответов 2xx/3xx/4xx/5xx | Позволяют отличать успешные ответы, редиректы, клиентские и серверные ошибки |
| Время ответа HTTP | Показывает скорость работы сервиса |
| p95/p99 latency | Показывает качество обслуживания большинства пользователей, а не только среднее значение |
| CPU usage | Важна, так как вычисления нагружают процессор |
| Load average | Позволяет понять, справляется ли сервер с вычислительной нагрузкой |
| RAM usage | Позволяет отследить нехватку памяти и риск OOM |
| Disk usage | Важна, так как отчёты сохраняются на диск |
| Inodes usage | Даже при наличии свободного места создание файлов невозможно, если закончились inodes |
| Количество созданных отчётов | Прикладная метрика, показывающая выполнение основной функции системы |
| Количество ошибок генерации отчётов | Позволяет отслеживать сбои в бизнес-операции |
| Время генерации отчёта | Показывает, насколько быстро клиент получает результат |
| Размер очереди задач | Важна, если вычисления выполняются асинхронно |

Итоговый минимальный набор:

```text
HTTP availability
HTTP request count
HTTP status codes
HTTP latency avg/p95/p99
CPU usage
Load average
RAM usage
Disk usage
Inodes usage
Report generation count
Report generation errors
Report generation time
Queue size, если есть очередь задач
```

---

## 2. Метрики для менеджера продукта

Менеджеру продукта не всегда понятны технические метрики уровня `RAM`, `CPU`, `inodes`, `load average`. Для него важнее видеть, насколько сервис выполняет обязательства перед клиентами и какое качество обслуживания предоставляет.

Поэтому для менеджера продукта лучше подготовить отдельный бизнес-дашборд.

| Техническая метрика | Понятная бизнес-интерпретация |
|---|---|
| CPU/RAM | Хватает ли мощности для обработки клиентских задач |
| Disk/inodes | Может ли система продолжать сохранять отчёты |
| HTTP 2xx/4xx/5xx | Успешность обслуживания клиентов |
| Latency p95/p99 | Как быстро клиент получает ответ |
| Error rate | Доля неуспешных операций |
| Report success rate | Доля успешно сформированных отчётов |
| Report generation time | Время подготовки отчёта |
| SLA/SLO | Выполняются ли обязательства перед клиентами |
| MTTR | Как быстро команда восстанавливает сервис после сбоя |

Для менеджера продукта можно предложить следующие показатели:

- доступность сервиса в процентах;
- процент успешных запросов;
- процент успешно сформированных отчётов;
- количество ошибок при генерации отчётов;
- среднее и p95/p99 время генерации отчёта;
- количество обращений клиентов;
- количество инцидентов;
- среднее время восстановления после инцидента;
- выполнение SLA/SLO за день, неделю и месяц.

Пример бизнес-дашборда:

```text
Доступность сервиса: 99.5%
Успешные HTTP-запросы: 98.7%
Успешно сформированные отчёты: 97.9%
Среднее время формирования отчёта: 12 секунд
p95 времени формирования отчёта: 25 секунд
Ошибки генерации отчётов: 3 за сутки
SLA за текущий месяц: 99.1%
```

Таким образом менеджер будет видеть не только техническое состояние сервера, а качество услуги для клиента.

---

## 3. Решение без системы сбора логов

По условию задачи DevOps-команде не выделили финансирование на построение полноценной системы сбора логов, но разработчики хотят видеть ошибки приложений.

В такой ситуации можно использовать уже имеющуюся систему мониторинга и локальное хранение логов.

Возможное решение:

1. Настроить приложение так, чтобы ошибки писались в файл, `stderr`, `journald` или `syslog`.
2. Настроить ротацию логов через `logrotate`.
3. Использовать агент мониторинга для чтения логов.
4. Создать триггеры на ключевые слова ошибок:
   - `ERROR`
   - `Exception`
   - `Traceback`
   - `Fatal`
   - `Critical`
5. Отправлять уведомления разработчикам в email, Telegram или другой корпоративный канал.

Примеры инструментов:

- `Zabbix agent log[] / logrt[]`;
- `Telegraf inputs.tail`;
- `journald`;
- `syslog`;
- простые shell-скрипты с отправкой уведомлений.

Такое решение не заменяет полноценные системы логирования уровня ELK, OpenSearch или Loki, но позволяет без дополнительной инфраструктуры получать информацию о критических ошибках приложения.

---

## 4. Ошибка в расчёте SLA

Формула из условия:

```text
summ_2xx_requests / summ_all_requests
```

При этом параметр не поднимается выше 70%, хотя в системе нет кодов ответа `5xx` и `4xx`.

Ошибка заключается в том, что в `summ_all_requests` входят не только `2xx`, но и другие HTTP-коды, например:

- `1xx`;
- `3xx`;
- возможно, технические или нестандартные ответы.

Если нет `4xx` и `5xx`, но доля `2xx` равна 70%, значит оставшиеся 30% — это, скорее всего, `3xx` редиректы.

Необходимо проверить распределение всех HTTP-кодов:

```text
2xx
3xx
4xx
5xx
```

Если `3xx` являются штатным поведением сервиса, формулу SLA можно изменить:

```text
(summ_2xx_requests + summ_allowed_3xx_requests) / summ_all_requests
```

Или устранить лишние редиректы, если они не должны происходить.

Итог: ошибка не в отсутствии `4xx/5xx`, а в том, что успешными считаются только `2xx`, хотя часть ответов может быть `3xx`.

---

## 5. Плюсы и минусы pull и push мониторинга

### Pull-модель

В pull-модели сервер мониторинга сам опрашивает наблюдаемые сервисы и забирает у них метрики.

Пример: Prometheus scrape targets.

Плюсы:

- централизованный контроль опроса;
- проще понимать, какой target доступен, а какой нет;
- удобно управлять частотой сбора метрик;
- хорошо подходит для service discovery;
- удобно использовать в Kubernetes и микросервисной архитектуре.

Минусы:

- сервер мониторинга должен иметь сетевой доступ к target;
- сложнее мониторить узлы за NAT или firewall;
- нужно открывать endpoint для метрик;
- при большом количестве targets требуется масштабирование.

### Push-модель

В push-модели агент или приложение само отправляет метрики в систему мониторинга.

Пример: Telegraf отправляет метрики в InfluxDB.

Плюсы:

- удобно для серверов за NAT или firewall;
- агент сам отправляет данные наружу;
- подходит для batch/job-задач;
- можно буферизовать данные на стороне агента;
- удобно для изолированных сетей.

Минусы:

- сложнее понять, что источник умер, а не просто перестал отправлять метрики;
- выше зависимость от корректной работы агента;
- есть риск перегрузки принимающей стороны;
- сложнее централизованно контролировать частоту отправки.

---

## 6. Классификация систем мониторинга

| Система | Модель |
|---|---|
| Prometheus | Pull, но есть Pushgateway и remote_write |
| TICK | Push, так как Telegraf отправляет метрики в InfluxDB |
| Zabbix | Гибридная модель |
| VictoriaMetrics | Гибридная модель |
| Nagios | В основном pull, но поддерживает passive checks |

### Prometheus

Prometheus преимущественно использует pull-модель: сам опрашивает HTTP endpoints `/metrics`.

Дополнительно возможны:

- Pushgateway;
- remote_write;
- exporters.

### TICK

TICK-стек преимущественно работает по push-модели.

Компоненты:

- Telegraf собирает метрики;
- InfluxDB хранит временные ряды;
- Chronograf предоставляет веб-интерфейс;
- Kapacitor используется для обработки данных и алертинга.

### Zabbix

Zabbix является гибридной системой.

Возможны два режима:

- passive checks — Zabbix Server сам опрашивает агента;
- active checks — Zabbix Agent сам отправляет данные серверу.

### VictoriaMetrics

VictoriaMetrics можно отнести к гибридным решениям.

Возможны варианты:

- приём метрик через Prometheus remote_write;
- сбор метрик через vmagent;
- работа в pull- и push-сценариях.

### Nagios

Nagios преимущественно работает по pull-модели: сервер выполняет проверки сервисов и хостов.

Также возможны passive checks, когда результаты проверок передаются в Nagios извне.

---

## 7. Практическая часть: запуск TICK-стека

Практическая часть выполнялась на собственном сервере `tick`.

### Проверка ОС

```bash
cat /etc/os-release
uname -a
whoami
```

Результат:

```text
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
Linux tick 6.1.0-49-amd64 x86_64 GNU/Linux
root
```

### Установка базовых пакетов

```bash
apt update
apt install -y git curl ca-certificates gnupg nano
```

### Установка Docker и Docker Compose

```bash
apt install -y docker.io docker-compose
```

Проверка версий:

```bash
docker --version
docker-compose --version
```

Результат:

```text
Docker version 20.10.24+dfsg1
docker-compose version 1.29.2
```

Проверка Docker:

```bash
docker run hello-world
```

Результат:

```text
Hello from Docker!
```

### Клонирование репозитория

```bash
mkdir -p /opt/dz-monitoring
cd /opt/dz-monitoring

git clone https://github.com/influxdata/sandbox.git
cd sandbox
```

Проверка содержимого:

```bash
ls -lah
```

В каталоге присутствовали:

```text
docker-compose.yml
sandbox
README.md
telegraf/
influxdb/
kapacitor/
chronograf/
documentation/
```

### Запуск TICK-стека

```bash
set -a
source .env-latest
set +a

docker-compose up -d --build
```

Проверка контейнеров:

```bash
docker-compose ps
```

Итоговое состояние контейнеров:

```text
sandbox_chronograf_1      Up      0.0.0.0:8888->8888/tcp
sandbox_documentation_1   Up      0.0.0.0:3010->3000/tcp
sandbox_influxdb_1        Up      0.0.0.0:8086->8086/tcp
sandbox_kapacitor_1       Up      0.0.0.0:9092->9092/tcp
sandbox_telegraf_1        Up      8092/udp, 8094/tcp, 8125/udp
```

Chronograf был доступен по адресу:

```text
http://192.168.1.87:8888
```

---

## 8. Настройка Docker-метрик в Telegraf

Для сбора Docker-метрик в конфигурацию Telegraf был добавлен input plugin:

```toml
[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
  timeout = "5s"
```

Также для доступа Telegraf к Docker API в `docker-compose.yml` был настроен проброс Docker socket:

```yaml
volumes:
  - ./telegraf/:/etc/telegraf/
  - /var/run/docker.sock:/var/run/docker.sock
```

Для учебного стенда был предоставлен доступ к Docker socket:

```bash
chmod 666 /var/run/docker.sock
```

После этого контейнер Telegraf был пересоздан:

```bash
docker-compose stop telegraf
docker-compose rm -f telegraf
docker-compose up -d telegraf
```

Проверка логов Telegraf:

```bash
docker-compose logs --tail=100 telegraf
```

Результат:

```text
Starting Telegraf 1.39.0
Loaded inputs: cpu docker influxdb system
Loaded outputs: influxdb
Tags enabled: host=telegraf-getting-started
```

---

## 9. Результаты проверки

Проверка баз данных InfluxDB:

```bash
docker exec -it sandbox_influxdb_1 influx -execute 'SHOW DATABASES'
```

Результат:

```text
name: databases
name
----
_internal
telegraf
```

Проверка measurements:

```bash
docker exec -it sandbox_influxdb_1 influx -database telegraf -execute 'SHOW MEASUREMENTS'
```

Результат:

```text
name: measurements
name
----
cpu
docker
docker_container_blkio
docker_container_cpu
docker_container_mem
docker_container_net
docker_container_status
influxdb
influxdb_cmdline
influxdb_cq
influxdb_database
influxdb_httpd
influxdb_memstats
influxdb_queryExecutor
influxdb_runtime
influxdb_shard
influxdb_subscriber
influxdb_system
influxdb_tsm1_cache
influxdb_tsm1_engine
influxdb_tsm1_filestore
influxdb_tsm1_wal
influxdb_udp
influxdb_write
system
```

Наличие следующих measurements подтверждает, что Docker-метрики успешно собираются:

```text
docker
docker_container_blkio
docker_container_cpu
docker_container_mem
docker_container_net
docker_container_status
```

---

## 10. Скриншоты

### Скриншот 1. Веб-интерфейс Chronograf

Адрес:

```text
http://192.168.1.87:8888
```

<img width="3071" height="1111" alt="image" src="https://github.com/user-attachments/assets/289cdcd0-78a1-474f-9192-0c20e9d01a60" />


---

### Скриншот 2. График утилизации CPU

Пример запроса:

```sql
SELECT mean("usage_system")
FROM "telegraf"."autogen"."cpu"
WHERE time > :dashboardTime:
GROUP BY time(:interval:), "host"
FILL(null)
```

<img width="3071" height="1091" alt="image" src="https://github.com/user-attachments/assets/c279af70-6711-4025-8c08-854a5db0b3bd" />
---

### Скриншот 3. Список Docker measurements


<img width="2890" height="1676" alt="image" src="https://github.com/user-attachments/assets/12c0a132-da85-4c90-bb64-a813becdacec" />

---

## 11. Вывод

В ходе выполнения домашнего задания были рассмотрены основные подходы к мониторингу инфраструктуры и приложений.

Были определены технические метрики, необходимые для контроля HTTP-платформы, выполняющей вычисления и сохраняющей отчёты на диск. Также были предложены бизнес-метрики, понятные менеджеру продукта: доступность сервиса, успешность операций, время ответа, время генерации отчётов и выполнение SLA/SLO.

В практической части на собственном сервере был развёрнут TICK-стек:

- InfluxDB;
- Telegraf;
- Chronograf;
- Kapacitor.

Был настроен сбор системных метрик и Docker-метрик через Telegraf. Метрики успешно поступили в базу `telegraf` в InfluxDB и стали доступны для отображения в Chronograf.

Практическая часть подтверждена доступностью Chronograf по адресу:

```text
http://192.168.1.87:8888
```

и наличием measurements:

```text
cpu
docker
docker_container_cpu
docker_container_mem
docker_container_net
system
```
---
<img width="3071" height="1662" alt="image" src="https://github.com/user-attachments/assets/f4b61c82-93c1-4a10-b330-0d90bd1bf332" />

<img width="3071" height="1649" alt="image" src="https://github.com/user-attachments/assets/8cf8a0fd-ada5-459c-b6c3-9fbb18dd18d9" />

<img width="3071" height="1640" alt="image" src="https://github.com/user-attachments/assets/f11feb73-66e1-4c48-9e41-82c2f7d3820c" />

---

