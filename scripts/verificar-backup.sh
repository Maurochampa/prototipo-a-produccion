#!/usr/bin/env bash
# Un backup que nunca probaste restaurar no es un backup.
# Restaura el último backup en una base temporal y verifica que los datos estén.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

set -a; . ./.env; set +a
read -r -a DK <<< "${DOCKER:-docker}"

mapfile -t backups < <(ls -1t backups/db-*.sql.gz 2>/dev/null || true)
if ((${#backups[@]} == 0)); then
    echo "✗ No hay backups en backups/ (corré antes ./scripts/backup.sh)" >&2
    exit 1
fi
ultimo="${backups[0]}"
prueba="verificacion_restore"

psql_db() { "${DK[@]}" compose exec -T db psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" "$@"; }

psql_db -d postgres -c "DROP DATABASE IF EXISTS $prueba" >/dev/null 2>&1
psql_db -d postgres -c "CREATE DATABASE $prueba" >/dev/null
trap 'psql_db -d postgres -c "DROP DATABASE IF EXISTS '"$prueba"'" >/dev/null 2>&1 || true' EXIT

zcat "$ultimo" | psql_db -d "$prueba" >/dev/null 2>&1

restauradas="$(psql_db -d "$prueba" -tAc 'SELECT count(*) FROM visitas')"
actuales="$(psql_db -d "$POSTGRES_DB" -tAc 'SELECT count(*) FROM visitas')"

if [[ ! "$restauradas" =~ ^[0-9]+$ ]]; then
    echo "✗ El restore no recuperó la tabla visitas" >&2
    exit 1
fi
echo "✓ Restore OK desde $ultimo: $restauradas visitas recuperadas (en producción hay $actuales)"
