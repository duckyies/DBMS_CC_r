#!/bin/bash
# Open a MySQL shell on the NEW (Python) stack. Pass a query as $1 to run it non-interactively.
cd "$(dirname "$0")"
set -a; . ./.env; set +a
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
if [ -n "$1" ]; then mysql -h127.0.0.1 -P"${DB_PORT:-3407}" -uroot "$MYSQL_DATABASE" -e "$1"; else mysql -h127.0.0.1 -P"${DB_PORT:-3407}" -uroot "$MYSQL_DATABASE"; fi
