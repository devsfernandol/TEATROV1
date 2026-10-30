#!/usr/bin/env bash
# Restaura la base TEATRO desde database/teatro.sql (borra los datos actuales)
# y asegura el usuario de la aplicación. Requiere el MySQL de desarrollo activo.

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

mysql_activo || { echo "✗ MySQL de desarrollo no está activo. Ejecute dev/iniciar.sh" >&2; exit 1; }

echo "→ Restaurando la base TEATRO desde database/teatro.sql ..."
mysql_root < "$RAIZ/database/teatro.sql"

mysql_root <<SQL
CREATE USER IF NOT EXISTS '$TEATRO_DB_USER'@'127.0.0.1' IDENTIFIED BY '$TEATRO_DB_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`TEATRO\`.* TO '$TEATRO_DB_USER'@'127.0.0.1';
SQL

echo "✓ Base de datos lista."
