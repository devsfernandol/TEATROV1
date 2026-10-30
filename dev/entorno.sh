# shellcheck shell=bash
# Variables del entorno de desarrollo local. Se cargan desde los demás scripts.
#
# El MySQL de desarrollo es una instancia propia del proyecto: corre con el
# usuario actual (sin sudo), escucha solo en 127.0.0.1 y guarda sus datos en
# .dev/, sin tocar el MySQL instalado en el sistema.

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="$RAIZ/.dev"
MYSQL_DATOS="$DEV_DIR/mysql"
MYSQL_SOCKET="$DEV_DIR/mysqld.sock"
MYSQL_PID="$DEV_DIR/mysqld.pid"
MYSQL_LOG="$DEV_DIR/mysqld.log"
PHP_LOG="$DEV_DIR/php.log"

MYSQL_PUERTO="${MYSQL_PUERTO:-3307}"
PHP_PUERTO="${PHP_PUERTO:-8000}"

# Credenciales que usa la aplicación (solo para este entorno local).
export TEATRO_DB_HOST=127.0.0.1
export TEATRO_DB_PORT="$MYSQL_PUERTO"
export TEATRO_DB_NAME=TEATRO
export TEATRO_DB_USER=teatro_app
export TEATRO_DB_PASSWORD=teatro_dev

# Cliente mysql como root de la instancia local (root solo es accesible por el socket).
mysql_root() {
    mysql --no-defaults --socket="$MYSQL_SOCKET" -uroot "$@"
}

mysql_activo() {
    mysqladmin --no-defaults --socket="$MYSQL_SOCKET" -uroot ping >/dev/null 2>&1
}
