#!/usr/bin/env bash
# Levanta el entorno de desarrollo: MySQL local del proyecto + servidor de PHP.
# Uso: dev/iniciar.sh   (Ctrl+C detiene el servidor de PHP; MySQL sigue activo)

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

mkdir -p "$DEV_DIR"

# 1. Inicializar el directorio de datos la primera vez.
if [[ ! -d "$MYSQL_DATOS" ]]; then
    echo "→ Inicializando MySQL de desarrollo en .dev/mysql ..."
    mysqld --no-defaults --initialize-insecure \
        --datadir="$MYSQL_DATOS" --user="$(whoami)" --log-error="$MYSQL_LOG"
fi

# 2. Arrancar MySQL si no está corriendo.
if ! mysql_activo; then
    echo "→ Iniciando MySQL en 127.0.0.1:$MYSQL_PUERTO ..."
    mysqld --no-defaults --daemonize \
        --datadir="$MYSQL_DATOS" --user="$(whoami)" \
        --socket="$MYSQL_SOCKET" --pid-file="$MYSQL_PID" --log-error="$MYSQL_LOG" \
        --port="$MYSQL_PUERTO" --bind-address=127.0.0.1 --mysqlx=OFF \
        --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

    for _ in $(seq 1 30); do
        mysql_activo && break
        sleep 1
    done
    mysql_activo || { echo "✗ MySQL no arrancó. Revise $MYSQL_LOG" >&2; exit 1; }
fi

# 3. Crear el usuario de la aplicación y restaurar la base si no existe.
if [[ -z "$(mysql_root -N -e "SHOW DATABASES LIKE 'TEATRO'")" ]]; then
    "$(dirname "$0")/reiniciar-bd.sh"
fi

# 4. PHP del proyecto (última versión estable, compilada desde php.net).
"$(dirname "$0")/instalar-php.sh"

# 5. Servidor de PHP.
echo "→ $("$PHP_BIN" -v | head -1)"
echo "→ Aplicación disponible en http://localhost:$PHP_PUERTO  (Ctrl+C para detener)"
cd "$RAIZ"
# Varios procesos en paralelo, como un servidor real (permite probar la concurrencia).
export PHP_CLI_SERVER_WORKERS="${PHP_CLI_SERVER_WORKERS:-8}"
exec "$PHP_BIN" -S "localhost:$PHP_PUERTO" -d display_errors=0 -d error_log="$PHP_LOG"
