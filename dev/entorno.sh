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

# Versión de PHP del entorno. Se compila con dev/instalar-php.sh.
# Para probar con otro PHP: PHP_BIN=/usr/bin/php dev/prueba-instalacion.sh
PHP_VERSION="8.5.12"
PHP_BIN="${PHP_BIN:-$DEV_DIR/php/bin/php}"

# Credenciales que usa la aplicación (solo para este entorno local).
export TEATRO_DB_HOST=127.0.0.1
export TEATRO_DB_PORT="$MYSQL_PUERTO"
export TEATRO_DB_NAME=TEATRO
export TEATRO_DB_USER=teatro_app
export TEATRO_DB_PASSWORD=teatro_dev

# Las pruebas hacen muchas compras y consultas desde la misma IP: se suben los
# límites por IP (los límites en sí se prueban en dev/prueba-instalacion.sh).
export TEATRO_LIMITE_COMPRAS_IP=100000
export TEATRO_LIMITE_CONSULTAS_IP=100000
export TEATRO_LIMITES_DIR="$DEV_DIR/limites"

# Cliente mysql como root de la instancia local (root solo es accesible por el socket).
mysql_root() {
    mysql --no-defaults --socket="$MYSQL_SOCKET" -uroot "$@"
}

mysql_activo() {
    mysqladmin --no-defaults --socket="$MYSQL_SOCKET" -uroot ping >/dev/null 2>&1
}
