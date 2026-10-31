#!/bin/bash
# Restaura los datos de demostración (lo ejecuta cron cada noche) para que
# siempre haya obras futuras y se descarten las compras de prueba.
# Reinicia PHP para invalidar las sesiones, que guardan números de venta.
set -euo pipefail
cd /opt/teatro

docker exec -i teatro-db sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < app/database/teatro.sql
docker restart teatro-php > /dev/null

echo "$(date -Is) Datos de demostración restaurados"
