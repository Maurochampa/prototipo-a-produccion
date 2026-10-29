#!/usr/bin/env bash
# Backup de PostgreSQL: dump comprimido con fecha, chequeado y con retención.
# Uso: ./scripts/backup.sh        (RETENER=14 ./scripts/backup.sh para guardar más)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

set -a; . ./.env; set +a
read -r -a DK <<< "${DOCKER:-docker}"
RETENER="${RETENER:-7}"

mkdir -p backups
archivo="backups/db-$(date +%Y%m%d-%H%M%S).sql.gz"
tmp="$archivo.tmp"
trap 'rm -f "$tmp"' EXIT

"${DK[@]}" compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists \
    | gzip -9 > "$tmp"

gzip -t "$tmp"
if [[ "$(zcat "$tmp" | tail -n 10)" != *"PostgreSQL database dump complete"* ]]; then
    echo "✗ El dump quedó incompleto" >&2
    exit 1
fi

mv "$tmp" "$archivo"
chmod 600 "$archivo"
echo "✓ Backup creado: $archivo ($(du -h "$archivo" | cut -f1))"

mapfile -t viejos < <(ls -1t backups/db-*.sql.gz | tail -n +"$((RETENER + 1))")
if ((${#viejos[@]} > 0)); then
    rm -f -- "${viejos[@]}"
    echo "✓ Borré ${#viejos[@]} backup(s) viejo(s); conservo los últimos $RETENER"
fi
