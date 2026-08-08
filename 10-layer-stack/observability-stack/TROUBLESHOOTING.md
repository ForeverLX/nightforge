# observability-stack troubleshooting

## Langfuse restart loop (resolved 2026-08-02)

`langfuse-web` and `langfuse-worker` sat in `Restarting (1)` indefinitely while
every other service reported healthy.

Two **independent** faults were stacked. Fixing either one alone leaves the loop
in place, so both are recorded here.

### Fault 1 — clustered ClickHouse migrations on a single node

`langfuse-web` died during its entrypoint migration step:

```
error: failed to open database: code: 139, message: There is no Zookeeper configuration in server config in line 0:
        CREATE TABLE schema_migrations ON CLUSTER default (
                version    Int64,
                dirty      UInt8,
                sequence   UInt64
        ) Engine=ReplicatedMergeTree ORDER BY sequence
Applying clickhouse migrations failed.
```

`ReplicatedMergeTree` and `ON CLUSTER` require a Zookeeper/ClickHouse Keeper
quorum to coordinate replicas. This deployment is a single ClickHouse node with
no Keeper, so the very first migration — creating `schema_migrations` — aborts.
The entrypoint `exit`s on migration failure, `restart: always` respawns it, loop.

Langfuse ships both migration sets and selects between them in
`/app/packages/shared/clickhouse/scripts/up.sh`:

```sh
if [ "$CLICKHOUSE_CLUSTER_ENABLED" == "false" ] ; then
  migrate -source file://clickhouse/migrations/unclustered ... x-migrations-table-engine=MergeTree
else
  migrate -source file://clickhouse/migrations/clustered   ... x-migrations-table-engine=ReplicatedMergeTree
fi
```

The flag **defaults to the clustered branch**, and our `docker-compose.yml` never
set it. Upstream's reference compose does set it in the shared env anchor.

**Fix** — in the `&langfuse-env` anchor, so web and worker both inherit it:

```yaml
CLICKHOUSE_CLUSTER_ENABLED: ${CLICKHOUSE_CLUSTER_ENABLED:-false}
```

Rejected alternatives:

- *Add Zookeeper/Keeper* — a whole extra service and quorum to operate purely to
  satisfy replication we do not want on one node.
- *PostgreSQL only* — not supported. Langfuse v3+ requires ClickHouse for traces
  and observations; Postgres alone is not a valid backend.

### Fault 2 — no `.env`, so every secret was a placeholder

`langfuse-worker` never reached the migration step. It crashed earlier, at env
validation:

```
ZodError: ENCRYPTION_KEY must be 256 bits, 64 string characters in hex format,
generate via: openssl rand -hex 32
```

`.env` did not exist. Compose fell back to the `${VAR:-REPLACE_*}` defaults in
`docker-compose.yml`, so `ENCRYPTION_KEY` was the literal
`REPLACE_WITH_64_HEX_CHAR_KEY` (28 chars, fails the exact-64 check).

**Fix** — generate a real `.env` (mode 600, gitignored via `*.env`):

```bash
cd ~/Github/nightforge/10-layer-stack/observability-stack
umask 077
{
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
  echo "CLICKHOUSE_PASSWORD=$(openssl rand -hex 24)"
  echo "REDIS_AUTH=$(openssl rand -hex 24)"
  echo "MINIO_ROOT_USER=lfminio$(openssl rand -hex 4)"
  echo "MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)"
  echo "SALT=$(openssl rand -base64 32)"
  echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
  echo "NEXTAUTH_SECRET=$(openssl rand -base64 32)"
  echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 16)"
  echo "CLICKHOUSE_CLUSTER_ENABLED=false"
} >> .env
```

Keep infrastructure passwords **hex/alphanumeric**. `POSTGRES_PASSWORD`,
`CLICKHOUSE_PASSWORD` and `REDIS_AUTH` are interpolated raw into `DATABASE_URL`
and the ClickHouse migration DSN — unencoded `@`, `/`, `#`, `?` corrupt the URL.
The entrypoint even lists this as a suspected cause on any migration failure,
which is a misleading hint when the real problem is the cluster flag.

### Volume wipe was required

Postgres, ClickHouse and MinIO bake credentials **at volume initialisation
only**. Those volumes had already been created with the `REPLACE_*` placeholders,
so new `.env` values would have auth-failed against the old baked-in ones.

The five Langfuse volumes were dropped; `prometheus_data` and `grafana_data` were
deliberately preserved. Verified lossless first — `system.tables` for database
`default` returned 0, i.e. the migration never once succeeded and no trace data
had ever been written.

```bash
docker compose down
docker volume rm \
  cr1mson-observability_langfuse_clickhouse_data \
  cr1mson-observability_langfuse_clickhouse_logs \
  cr1mson-observability_langfuse_minio_data \
  cr1mson-observability_langfuse_postgres_data \
  cr1mson-observability_langfuse_redis_data
docker compose up -d
```

This is the one sanctioned exception to the README's "do not destroy volumes"
rule, and it applies only to a stack that has never successfully started. Once
Langfuse holds real traces, rotating these passwords is a migration, not a wipe.

### Grafana kept the placeholder password (caught during verification)

`grafana_data` was **deliberately preserved** through the wipe, which meant Grafana
kept the admin password baked in at its first init — the literal
`REPLACE_BEFORE_START`. `GF_SECURITY_ADMIN_PASSWORD` is applied only when Grafana
initialises its database; it is *not* re-applied on later boots. Adding the real
password to `.env` therefore had no effect, and the placeholder still authenticated:

```
curl -u admin:REPLACE_BEFORE_START 127.0.0.1:31746/api/datasources  -> 200
curl -u admin:<real .env password>  127.0.0.1:31746/api/datasources -> 401
```

Fixed without destroying the volume (dashboards and history preserved):

```bash
GP=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d= -f2)
docker exec cr1mson-observability-grafana-1 \
  grafana cli --homepath /usr/share/grafana admin reset-admin-password "$GP"
```

Now 200 with the `.env` password, 401 with the placeholder, Prometheus datasource
still wired to `http://127.0.0.2:31745`.

General rule: **any service that only reads a credential at volume-init time will
silently ignore a later `.env` change.** That applies to Postgres, ClickHouse,
MinIO and Grafana here. Postgres/ClickHouse/MinIO required the wipe; Grafana has a
CLI escape hatch. Always verify a rotated password actually took effect by
confirming the *old* one now fails.

### Verification

```
langfuse-web      RestartCount=0    Up (healthy)
langfuse-worker   RestartCount=0    Up
ZodError / "no Zookeeper configuration" / "ON CLUSTER"   0 occurrences
clickhouse default: 14 tables, 0 Replicated engines
schema_migrations: version 46, dirty 0
curl 127.0.0.1:31747/api/public/health -> {"status":"OK","version":"4.1.0"}
```

Unaffected, re-checked after the recreate:

```
prometheus  127.0.0.2:31745/-/ready    200   (targets: agentgateway up, node up)
grafana     127.0.0.1:31746/api/health 200
node-exporter 127.0.0.1:31750/metrics  200
otel-collector 127.0.0.1:31744         tcp open
```

### If it recurs

1. `docker compose logs langfuse-web --tail 60` — migration/Zookeeper errors.
2. `docker compose logs langfuse-worker --tail 60` — `ZodError` env failures.
   The two services fail for different reasons; always read both.
3. `docker compose config | grep CLICKHOUSE_CLUSTER_ENABLED` must render
   `"false"`. If `.env` is missing, compose silently uses the `REPLACE_*`
   defaults instead of erroring — check `.env` exists before anything else.
