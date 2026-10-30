#!/usr/bin/env bash
# Detiene el MySQL de desarrollo del proyecto (los datos se conservan en .dev/).

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

if mysql_activo; then
    mysqladmin --no-defaults --socket="$MYSQL_SOCKET" -uroot shutdown
    echo "✓ MySQL de desarrollo detenido."
else
    echo "MySQL de desarrollo no estaba activo."
fi
