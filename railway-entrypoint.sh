#!/bin/bash
# Railway entrypoint for Odoo 19: odoo.conf from env, database created on first
# boot with the generated admin password, prefork workers behind Caddy on $PORT,
# nightly backup to the Railway bucket.
set -euo pipefail

DB=${ODOO_DB:-odoo}
CONF=/etc/odoo/odoo.conf
# Empty = auto: 2 workers, or single-process mode when the plan gives this service
# under 1 GB (Railway sets the cgroup limit to the plan cap). Measured: ~500 MB with
# workers, ~320 MB single-process, with 8 apps and their assets loaded.
mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
WORKERS=${ODOO_WORKERS:-$([ "$mem" != max ] && [ "$mem" -lt 1000000000 ] && echo 0 || echo 2)}
# Odoo 19 reads ODOO_<option> env vars itself and crashes on an empty one.
[ -n "${ODOO_WORKERS:-}" ] || unset ODOO_WORKERS
# An array, not a function: a backgrounded function runs in a subshell that
# swallows SIGTERM instead of passing it on to Odoo.
AS_ODOO=(setpriv --reuid=odoo --regid=odoo --init-groups env HOME=/var/lib/odoo)

# Railway volumes mount root-owned; the image runs Odoo as the unprivileged odoo user.
chown odoo:odoo /var/lib/odoo

# Rewritten on every boot so variable changes apply on redeploy.
# Memory/time limits are the values from Odoo's deployment docs.
cat > "$CONF" <<EOF
[options]
data_dir = /var/lib/odoo
db_host = $PGHOST
db_port = $PGPORT
db_user = $PGUSER
db_password = $PGPASSWORD
db_name = $DB
admin_passwd = $ODOO_MASTER_PASSWORD
list_db = ${ODOO_DB_MANAGER:-false}
proxy_mode = True
http_interface = 127.0.0.1
http_port = 8069
gevent_port = 8072
workers = $WORKERS
max_cron_threads = 1
limit_memory_soft = 629145600
limit_memory_hard = 1677721600
limit_time_cpu = 600
limit_time_real = 1200
EOF
chown root:odoo "$CONF"
chmod 640 "$CONF"

# On a fresh deploy Postgres may still be starting.
for _ in $(seq 60); do pg_isready -q -d postgres && break; sleep 2; done

# First boot: no database, or the empty one Postgres created -> build it with the
# generated admin password (never admin/admin, not even for a moment). Only a
# definite "0" gets here; a failed query skips it, so this can't drop real data.
if [ "$(psql -d postgres -tAc "SELECT count(*) FROM pg_database WHERE datname = '$DB'")" = 0 ] ||
   [ "$(psql -d "$DB" -tAc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")" = 0 ]; then
  echo "railway: first boot, creating database $DB"
  "${AS_ODOO[@]}" odoo db -c "$CONF" init "$DB" --force --username admin --password "$ODOO_ADMIN_PASSWORD" 2>&1
  # Odoo logs a failed init instead of exiting non-zero; don't serve a half-built database.
  [ "$(psql -d "$DB" -tAc "SELECT state FROM ir_module_module WHERE name = 'base'")" = installed ]
fi

# Prefork workers answer websockets on the gevent port; threaded mode (0) on 8069.
export ODOO_WS_PORT=$([ "$WORKERS" = 0 ] && echo 8069 || echo 8072)
trap 'kill $(jobs -p) 2>/dev/null; wait; exit 0' TERM INT

# Odoo logs everything to stderr, which Railway paints red as errors; send it to stdout.
"${AS_ODOO[@]}" odoo -c "$CONF" 2>&1 &
odoo_pid=$!
XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp "${AS_ODOO[@]}" caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
caddy_pid=$!

if [ -n "${S3_BUCKET:-}" ]; then
  # 03:00 UTC daily; a failed backup is logged, it never takes Odoo down.
  while sleep $(( (97200 - $(date +%s) % 86400) % 86400 )); do odoo-backup || true; done &
fi

# Odoo or Caddy exiting means the service is broken: exit so Railway restarts it.
wait -n "$odoo_pid" "$caddy_pid"
exit 1
