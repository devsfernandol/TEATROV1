#!/usr/bin/env bash
# Simula la instalación que hará el evaluador y la prueba completa:
#   1. Genera el ZIP de entrega y revisa su contenido.
#   2. Lo descomprime en una carpeta limpia, dentro de una subcarpeta /teatro/.
#   3. Restaura la base desde el .sql del paquete (dos veces, para comprobar
#      que se puede reimportar).
#   4. Sirve esa copia con PHP 8.5.12 y ejecuta todas las pruebas (dev/pruebas.sh).
#   5. Comprueba que, con la base caída o con credenciales incorrectas, el usuario
#      ve una página amigable sin detalles técnicos y el detalle queda en el log.
#
# Requiere el MySQL de desarrollo activo (dev/iniciar.sh). No toca la copia de trabajo.
# Uso: dev/prueba-instalacion.sh [referencia]   (por defecto HEAD)

set -uo pipefail
source "$(dirname "$0")/entorno.sh"

REF="${1:-HEAD}"
PUERTO_APP=8001
PUERTO_SIN_BD=8002
PUERTO_CLAVE_MALA=8003

TMP="$(mktemp -d)"
PIDS=()
limpiar() {
    for pid in "${PIDS[@]}"; do
        pkill -P "$pid" 2>/dev/null
        kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
    rm -rf "$TMP"
}
trap limpiar EXIT

FALLOS=0
TOTAL=0
ok()    { TOTAL=$((TOTAL + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
falla() { TOTAL=$((TOTAL + 1)); FALLOS=$((FALLOS + 1)); printf '  \033[31m✗ %s\033[0m\n    %s\n' "$1" "$2"; }
igual() { if [[ "$2" == "$3" ]]; then ok "$1"; else falla "$1" "esperado: '$3' · obtenido: '$2'"; fi; }
contiene()    { if grep -qF -- "$3" "$2"; then ok "$1"; else falla "$1" "no se encontró: '$3'"; fi; }
no_contiene() { if grep -qF -- "$3" "$2"; then falla "$1" "se encontró: '$3'"; else ok "$1"; fi; }

# servir PUERTO LOG [VAR=valor ...] -> levanta PHP sobre la carpeta de instalación
servir() {
    local puerto="$1" log="$2"
    shift 2
    env "$@" PHP_CLI_SERVER_WORKERS=8 \
        "$PHP_BIN" -S "localhost:$puerto" -t "$TMP/www" -d display_errors=0 -d error_log="$log" \
        >/dev/null 2>&1 &
    PIDS+=("$!")
    for _ in $(seq 1 20); do
        curl -s -o /dev/null "http://localhost:$puerto/" && return 0
        sleep 0.25
    done
    echo "✗ No arrancó el servidor en el puerto $puerto" >&2
    exit 1
}

mysql_activo || { echo "✗ MySQL de desarrollo no está activo. Ejecute dev/iniciar.sh" >&2; exit 1; }
[[ -x "$PHP_BIN" ]] || "$(dirname "$0")/instalar-php.sh"

# -----------------------------------------------------------------------------
echo "Paquete de entrega ($REF)"
"$(dirname "$0")/empaquetar.sh" "$REF" >/dev/null
ZIP="$RAIZ/dist/teatro.zip"
python3 -I -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$ZIP" > "$TMP/contenido.txt"

for requerido in teatro/index.php teatro/comprar.php teatro/confirmacion.php teatro/LEAME.md teatro/database/teatro.sql \
                teatro/docker-compose.yml teatro/.env.example teatro/docker/Dockerfile teatro/docker/php-fpm.conf \
                teatro/docker/nginx.conf teatro/docker/fastcgi.conf teatro/docker/php.ini \
                teatro/docker/db-init/02-usuario.sh teatro/docker/demasiadas-solicitudes.html; do
    contiene "Incluye $requerido" "$TMP/contenido.txt" "$requerido"
done
no_contiene "No incluye herramientas de desarrollo (dev/)" "$TMP/contenido.txt" "teatro/dev/"
no_contiene "No incluye datos locales (.dev/)" "$TMP/contenido.txt" "teatro/.dev/"
no_contiene "No incluye el despliegue propio del autor (deploy/)" "$TMP/contenido.txt" "teatro/deploy/"
igual "No incluye un .env con claves" "$(grep -cx 'teatro/.env' "$TMP/contenido.txt")" "0"
igual "No incluye credenciales locales (config.local.php)" "$(grep -cx 'teatro/includes/config.local.php' "$TMP/contenido.txt")" "0"
no_contiene "No incluye el enunciado (PDF)" "$TMP/contenido.txt" ".pdf"
igual "No incluye el README de desarrollo" "$(grep -cx 'teatro/README.md' "$TMP/contenido.txt")" "0"
igual "La primera página se llama index" "$(grep -c '^teatro/index\.' "$TMP/contenido.txt")" "1"

mkdir -p "$TMP/www"
python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$ZIP" "$TMP/www"
ok "Se descomprimió en una carpeta limpia (subcarpeta /teatro/)"

# -----------------------------------------------------------------------------
echo "Restauración de la base de datos desde el paquete"
SQL="$TMP/www/teatro/database/teatro.sql"
if mysql_root < "$SQL" 2> "$TMP/sql1.err"; then ok "Primera importación sin errores"; else falla "Primera importación sin errores" "$(cat "$TMP/sql1.err")"; fi
if mysql_root < "$SQL" 2> "$TMP/sql2.err"; then ok "Reimportación sin errores"; else falla "Reimportación sin errores" "$(cat "$TMP/sql2.err")"; fi
igual "Crea el esquema TEATRO con las tablas OBRA y VENTAS" \
    "$(mysql_root -N -B -e "SELECT GROUP_CONCAT(TABLE_NAME ORDER BY TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'TEATRO'")" "OBRA,VENTAS"
igual "OBRA tiene exactamente los campos del enunciado" \
    "$(mysql_root -N -B -e "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'TEATRO' AND TABLE_NAME = 'OBRA'")" \
    "cod_obra,nombre,fecha_obra,aforo,disponibles,sala"
igual "VENTAS tiene exactamente los campos del enunciado" \
    "$(mysql_root -N -B -e "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'TEATRO' AND TABLE_NAME = 'VENTAS'")" \
    "numero_venta,cod_obra,comprador,fecha_compra"
igual "numero_venta es autoincremental" \
    "$(mysql_root -N -B -e "SELECT EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'TEATRO' AND TABLE_NAME = 'VENTAS' AND COLUMN_NAME = 'numero_venta'")" "auto_increment"
igual "Ambas tablas usan InnoDB (transacciones)" \
    "$(mysql_root -N -B -e "SELECT GROUP_CONCAT(DISTINCT ENGINE) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'TEATRO'")" "InnoDB"
igual "La reimportación deja los datos iniciales (7 obras, 10 ventas)" \
    "$(mysql_root -N -B TEATRO -e 'SELECT CONCAT((SELECT COUNT(*) FROM OBRA), ",", (SELECT COUNT(*) FROM VENTAS))')" "7,10"
if mysql_root TEATRO -e 'UPDATE OBRA SET disponibles = aforo + 1 WHERE cod_obra = 1' 2>/dev/null; then
    falla "La base rechaza disponibles > aforo (CHECK)" "el UPDATE fue aceptado"
else
    ok "La base rechaza disponibles > aforo (CHECK)"
fi
if mysql_root TEATRO -e "INSERT INTO VENTAS (cod_obra, comprador) VALUES (999, 'V12345678')" 2>/dev/null; then
    falla "La base rechaza ventas de obras inexistentes (clave foránea)" "el INSERT fue aceptado"
else
    ok "La base rechaza ventas de obras inexistentes (clave foránea)"
fi

# -----------------------------------------------------------------------------
echo
echo "Pruebas funcionales sobre la copia instalada (http://localhost:$PUERTO_APP/teatro/)"
servir "$PUERTO_APP" "$TMP/php-app.log" \
    TEATRO_DB_HOST="$TEATRO_DB_HOST" TEATRO_DB_PORT="$TEATRO_DB_PORT" \
    TEATRO_DB_USER="$TEATRO_DB_USER" TEATRO_DB_PASSWORD="$TEATRO_DB_PASSWORD"
if PRUEBAS_PHP_LOG="$TMP/php-app.log" "$(dirname "$0")/pruebas.sh" "http://localhost:$PUERTO_APP/teatro" > "$TMP/funcionales.txt" 2>&1; then
    ok "Pruebas funcionales: $(tail -1 "$TMP/funcionales.txt" | sed 's/\x1b\[[0-9;]*m//g')"
else
    falla "Pruebas funcionales" "$(grep -A1 '✗' "$TMP/funcionales.txt" | sed 's/\x1b\[[0-9;]*m//g')"
fi

# -----------------------------------------------------------------------------
echo
echo "Fallos de infraestructura: el usuario nunca ve un error técnico"
# comprobar_fallo PUERTO LOG DESCRIPCIÓN
comprobar_fallo() {
    local puerto="$1" log="$2" caso="$3" pagina
    # Una entrada ajena se rechaza sin consultar la base, así que no depende de ella.
    igual "$caso: /teatro/confirmacion.php?venta=1 responde 404 sin consultar la base" \
        "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$puerto/teatro/confirmacion.php?venta=1")" "404"
    igual "$caso: enviar una compra responde 500" \
        "$(curl -s -o /dev/null -w '%{http_code}' -d 'token=x&identificador=V12345678' "http://localhost:$puerto/teatro/comprar.php?obra=1")" "500"
    for pagina in "" "index.php" "comprar.php?obra=1"; do
        igual "$caso: /teatro/$pagina responde 500" "$(curl -s -o "$TMP/fallo.html" -w '%{http_code}' "http://localhost:$puerto/teatro/$pagina")" "500"
    done
    contiene "$caso: muestra un mensaje amigable" "$TMP/fallo.html" "Servicio no disponible"
    for tecnico in SQLSTATE PDO Exception "$RAIZ" "/tmp/" "Stack trace" "$TEATRO_DB_PASSWORD" clave_incorrecta "Fatal error" "Warning:"; do
        no_contiene "$caso: no muestra '$tecnico'" "$TMP/fallo.html" "$tecnico"
    done
    contiene "$caso: el detalle técnico queda en el log del servidor" "$log" "[TEATRO] PDOException"
    no_contiene "$caso: el log no contiene la contraseña" "$log" "$TEATRO_DB_PASSWORD"
    no_contiene "$caso: el log no contiene la contraseña incorrecta" "$log" "clave_incorrecta"
}

servir "$PUERTO_SIN_BD" "$TMP/php-sin-bd.log" \
    TEATRO_DB_HOST=127.0.0.1 TEATRO_DB_PORT=3999 \
    TEATRO_DB_USER="$TEATRO_DB_USER" TEATRO_DB_PASSWORD="$TEATRO_DB_PASSWORD"
comprobar_fallo "$PUERTO_SIN_BD" "$TMP/php-sin-bd.log" "Base de datos caída"

servir "$PUERTO_CLAVE_MALA" "$TMP/php-clave.log" \
    TEATRO_DB_HOST="$TEATRO_DB_HOST" TEATRO_DB_PORT="$TEATRO_DB_PORT" \
    TEATRO_DB_USER="$TEATRO_DB_USER" TEATRO_DB_PASSWORD=clave_incorrecta
comprobar_fallo "$PUERTO_CLAVE_MALA" "$TMP/php-clave.log" "Credenciales incorrectas"

# -----------------------------------------------------------------------------
echo
echo "Configuración documentada en el LEAME (includes/config.local.php)"
# Se sigue el paso 3 del LEAME al pie de la letra: copiar el ejemplo y editarlo.
CONFIG_LOCAL="$TMP/www/teatro/includes/config.local.php"
cp "$TMP/www/teatro/includes/config.local.example.php" "$CONFIG_LOCAL"
sed -i "s/'host'     => 'localhost'/'host'     => '$TEATRO_DB_HOST'/; s/'port'     => 3306/'port'     => $TEATRO_DB_PORT/; \
        s/'user'     => 'root'/'user'     => '$TEATRO_DB_USER'/; s/'password' => ''/'password' => '$TEATRO_DB_PASSWORD'/" "$CONFIG_LOCAL"
servir 8004 "$TMP/php-config.log"
curl -s -o "$TMP/config.html" -w '%{http_code}' "http://localhost:8004/teatro/" > "$TMP/config.code"
igual "Con credenciales en config.local.php la aplicación conecta" "$(cat "$TMP/config.code")" "200"
igual "y muestra las 5 obras" "$(grep -c 'class="tarjeta obra"' "$TMP/config.html")" "5"

# Modo de diagnóstico: se activa la línea 'debug' del ejemplo y se apunta a un puerto sin MySQL.
sed -i "s|// 'debug' => true,|'debug' => true,|; s/'port'     => $TEATRO_DB_PORT/'port'     => 3999/" "$CONFIG_LOCAL"
servir 8005 "$TMP/php-debug.log"
curl -s -o "$TMP/debug.html" "http://localhost:8005/teatro/"
contiene "Con 'debug' => true se muestra el detalle técnico del error" "$TMP/debug.html" "SQLSTATE"
rm -f "$CONFIG_LOCAL"

"$(dirname "$0")/reiniciar-bd.sh" >/dev/null

echo
if [[ $FALLOS -eq 0 ]]; then
    printf '\033[32m✓ Instalación verificada: %d comprobaciones correctas, más la suite funcional completa.\033[0m\n' "$TOTAL"
else
    printf '\033[31m✗ %d de %d comprobaciones fallaron.\033[0m\n' "$FALLOS" "$TOTAL"
    exit 1
fi
