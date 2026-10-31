#!/usr/bin/env bash
# Prueba el instalador (instalar.sh) tal como lo usará el evaluador, en un Linux con Docker:
#   1. MySQL nuevo en Docker: instalar, comprar, actualizar conservando datos, empezar de cero.
#   2. MySQL existente en el mismo servidor, por socket (con un primer intento de clave incorrecta).
#   3. MySQL existente por red (localhost:puerto), conservando la base que ya tiene.
#   4. Desinstalar.
# Usa un proyecto de Docker propio (teatroprueba) y el puerto 127.0.0.1:8191: no toca
# otras instalaciones del servidor. Para el "MySQL existente" levanta un MySQL desechable.
#
# Uso: dev/prueba-docker.sh usuario@servidor   (empaqueta HEAD, lo copia y lo prueba allí)
#      dev/prueba-docker.sh --local teatro.zip  (en esta máquina, si tiene Docker)

set -uo pipefail

if [[ "${1:-}" != --local ]]; then
    DESTINO="${1:?Uso: dev/prueba-docker.sh usuario@servidor | --local teatro.zip}"
    # shellcheck disable=SC2206
    SSH=(ssh ${SSH_OPTS:-} "$DESTINO")
    "$(dirname "$0")/empaquetar.sh" >/dev/null
    RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
    REMOTO="/tmp/teatro-prueba-docker"
    "${SSH[@]}" "rm -rf $REMOTO && mkdir -p $REMOTO"
    "${SSH[@]}" "cat > $REMOTO/teatro.zip" < "$RAIZ/dist/teatro.zip"
    "${SSH[@]}" "cat > $REMOTO/prueba-docker.sh" < "$0"
    "${SSH[@]}" "bash $REMOTO/prueba-docker.sh --local $REMOTO/teatro.zip; r=\$?; rm -rf $REMOTO; exit \$r"
    exit
fi

ZIP="$(realpath "${2:?Falta el ZIP}")"
export COMPOSE_PROJECT_NAME=teatroprueba
PUERTO=127.0.0.1:8191
URL="http://$PUERTO"
EXTERNO=teatroprueba-mysql-externo
CLAVE_RAIZ=Raiz.Prueba-2026
TMP="$(mktemp -d)"

limpiar() {
    if [[ -d "$TMP/teatro" ]]; then
        (cd "$TMP/teatro" && docker compose down -v --remove-orphans >/dev/null 2>&1)
    fi
    docker rm -f "$EXTERNO" >/dev/null 2>&1
    docker volume rm teatroprueba_datos-mysql >/dev/null 2>&1
    docker image rm teatro-php >/dev/null 2>&1
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

# instalar "descripción" "respuestas"  -> ejecuta el instalador con esas respuestas
instalar() {
    local salida="$TMP/instalar-$((TOTAL + 1)).log"
    if printf '%b' "$2" | ./instalar.sh > "$salida" 2>&1; then
        ok "$1"
    else
        falla "$1" "$(tail -15 "$salida")"
    fi
    ULTIMA_SALIDA="$salida"
}

codigo() { curl -s -o /dev/null -w '%{http_code}' "$URL$1"; }
valor_env() { sed -n "s/^$1=//p" .env | sed "s/^'\(.*\)'$/\1/"; }

# comprar COD_OBRA IDENTIFICADOR -> imprime el número de entrada que muestra la confirmación
comprar() {
    local cj="$TMP/cookies-$RANDOM" token
    token=$(curl -s -c "$cj" -b "$cj" "$URL/comprar.php?obra=$1" | grep -oE 'name="token" value="[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}')
    curl -s -L -c "$cj" -b "$cj" -d "token=$token&identificador=$2" "$URL/comprar.php?obra=$1" \
        | grep -A2 'Número de entrada' | grep -oE '[0-9]+' | head -1
}

pagina_principal() {
    curl -s "$URL/" > "$TMP/index.html"
    igual "$1: la página principal muestra las 5 obras" "$(grep -c 'class="tarjeta obra"' "$TMP/index.html")" "5"
}

externo_sql() { docker exec -i -e MYSQL_PWD="$CLAVE_RAIZ" "$EXTERNO" mysql -uroot -N -B "$@"; }

# -----------------------------------------------------------------------------
echo "Paquete"
cd "$TMP" || exit 1
if command -v unzip >/dev/null; then
    unzip -q "$ZIP"
else
    # Sin unzip: se extrae con Python, respetando los permisos como lo hace unzip.
    python3 -I -c 'import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for i in z.infolist():
    z.extract(i)
    if i.external_attr >> 16:
        os.chmod(i.filename, (i.external_attr >> 16) & 0o777)' "$ZIP"
fi
cd teatro || exit 1
ok "Se descomprimió el paquete"
igual "instalar.sh es ejecutable" "$([[ -x instalar.sh ]] && echo sí)" "sí"
if docker compose config > "$TMP/config.txt" 2>&1; then
    falla "Sin instalar, docker compose se niega a arrancar (no hay clave por defecto)" "arrancó sin .env"
else
    contiene "Sin instalar, docker compose se niega a arrancar (no hay clave por defecto)" "$TMP/config.txt" "Ejecute ./instalar.sh"
fi

# -----------------------------------------------------------------------------
echo
echo "1. MySQL nuevo en Docker"
instalar "Instalación (opción 1)" "1\n$PUERTO\n-06:00\n"
contiene "Informa que Teatro está funcionando" "$ULTIMA_SALIDA" "Teatro está funcionando"
igual ".env tiene permisos 600" "$(stat -c %a .env)" "600"
CLAVE_DOCKER="$(valor_env TEATRO_DB_PASSWORD)"
igual "La clave de MySQL es aleatoria (48 caracteres hexadecimales)" "$([[ "$CLAVE_DOCKER" =~ ^[0-9a-f]{48}$ ]] && echo sí)" "sí"
igual "MySQL no publica ningún puerto" "$(docker inspect --format '{{json .HostConfig.PortBindings}}' "$(docker compose ps -q db)")" "{}"
igual "La red de la base es interna (sin salida a internet)" \
    "$(docker network inspect teatroprueba_datos --format '{{.Internal}}')" "true"
pagina_principal "Docker"
igual "La primera compra genera la entrada 11" "$(comprar 3 V-12345678)" "11"
igual "OBRA.disponibles de la obra 3 bajó de 2 a 1" \
    "$(docker compose exec -T -e MYSQL_PWD="$CLAVE_DOCKER" db mysql -uteatro_app -N -B TEATRO -e 'SELECT disponibles FROM OBRA WHERE cod_obra = 3')" "1"
for interno in /database/teatro.sql /.env /.env.example /instalar.sh /docker/instalar-bd.php /includes/config.php /docker-compose.yml /LEAME.md; do
    igual "$interno responde 404" "$(codigo "$interno")" "404"
done
igual "teatro_app no tiene permisos fuera de TEATRO" \
    "$(docker compose exec -T -e MYSQL_PWD="$CLAVE_DOCKER" db mysql -uteatro_app -N -B -e 'SHOW DATABASES' | grep -vc -e '^TEATRO$' -e '^information_schema$' -e '^performance_schema$')" "0"

instalar "Volver a instalar: actualizar conservando los datos" "1\n1\n$PUERTO\n-06:00\n"
igual "Conserva la clave de MySQL" "$(valor_env TEATRO_DB_PASSWORD)" "$CLAVE_DOCKER"
igual "Conserva la venta registrada (la siguiente compra es la 12)" "$(comprar 1 V-22222222)" "12"

instalar "Ver el estado (opción 3)" "3\n"
contiene "El estado informa que la aplicación responde" "$ULTIMA_SALIDA" "La aplicación responde"

instalar "Volver a instalar: empezar de cero" "1\n2\n$PUERTO\n-06:00\n"
igual "Empezar de cero restaura los datos de ejemplo (la siguiente compra vuelve a ser la 11)" "$(comprar 3 V-33333333)" "11"

docker compose stop db >/dev/null 2>&1
igual "Con MySQL detenido, la página responde 500" "$(curl -s -o "$TMP/caida.html" -w '%{http_code}' "$URL/")" "500"
contiene "y muestra un mensaje amigable" "$TMP/caida.html" "Servicio no disponible"
no_contiene "sin detalles técnicos" "$TMP/caida.html" "SQLSTATE"
docker compose start db >/dev/null 2>&1

# -----------------------------------------------------------------------------
echo
echo "2. MySQL existente en este servidor (socket)"
mkdir -p "$TMP/mysqld"
docker run -d --name "$EXTERNO" -e MYSQL_ROOT_PASSWORD="$CLAVE_RAIZ" \
    -v "$TMP/mysqld:/var/run/mysqld" -p 172.17.0.1:3399:3306 mysql:8.4 >/dev/null
for _ in $(seq 1 60); do
    docker exec -e MYSQL_PWD="$CLAVE_RAIZ" "$EXTERNO" mysqladmin -uroot -h127.0.0.1 ping >/dev/null 2>&1 && break
    sleep 2
done
igual "MySQL desechable listo, con su socket en $TMP/mysqld" "$([[ -S "$TMP/mysqld/mysqld.sock" ]] && echo sí)" "sí"

instalar "Instalación (opción 2, socket), con un primer intento de clave incorrecta" \
    "2\n1\n$TMP/mysqld/mysqld.sock\nroot\nclave-mala\nroot\n$CLAVE_RAIZ\ns\n$PUERTO\n"
contiene "Con la clave incorrecta muestra el error de MySQL" "$ULTIMA_SALIDA" "Access denied"
contiene "Avisa que los datos del MySQL en Docker anterior se conservan" "$ULTIMA_SALIDA" "teatroprueba_datos-mysql"
igual "Modo guardado en .env" "$(valor_env TEATRO_MODO)" "socket"
no_contiene ".env no guarda la clave de root" .env "$CLAVE_RAIZ"
igual "Ya no corre el MySQL en Docker" "$(docker compose ps -q db 2>/dev/null | grep -c .)" "0"
igual "Importó la base en el MySQL existente (7 obras)" "$(externo_sql TEATRO -e 'SELECT COUNT(*) FROM OBRA')" "7"
igual "Creó 'teatro_app'@'localhost' con permisos mínimos" \
    "$(externo_sql -e "SHOW GRANTS FOR 'teatro_app'@'localhost'" | grep -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON `TEATRO`')" "1"
pagina_principal "Socket"
igual "La primera compra genera la entrada 11" "$(comprar 3 V-44444444)" "11"

# -----------------------------------------------------------------------------
echo
echo "3. MySQL existente por red (localhost:3399), conservando la base"
instalar "Instalación (opción 2, red)" "2\n2\nlocalhost\n3399\nroot\n$CLAVE_RAIZ\n1\ns\n$PUERTO\n"
contiene "Traduce localhost a host.docker.internal" "$ULTIMA_SALIDA" "host.docker.internal"
contiene "Detecta que la base TEATRO ya existe" "$ULTIMA_SALIDA" "La base TEATRO ya existe"
igual "Modo guardado en .env" "$(valor_env TEATRO_MODO)" "red"
igual "Creó 'teatro_app'@'%'" "$(externo_sql -e "SELECT COUNT(*) FROM mysql.user WHERE user = 'teatro_app' AND host = '%'")" "1"
pagina_principal "Red"
igual "Conservó la venta anterior (la siguiente compra es la 12)" "$(comprar 1 V-55555555)" "12"

# -----------------------------------------------------------------------------
echo
echo "4. Desinstalar"
instalar "Desinstalar (opción 4), borrando también los datos del MySQL en Docker" "4\ns\ns\n"
igual "No quedan contenedores de Teatro" "$(docker ps -aq --filter label=com.docker.compose.project=teatroprueba | grep -c .)" "0"
igual "Se borró el volumen de datos" "$(docker volume ls -q --filter name=teatroprueba_datos-mysql | grep -c .)" "0"
igual "Se borró .env" "$([[ -f .env ]] && echo existe || echo no)" "no"
contiene "Explica cómo quitar la base del MySQL existente" "$ULTIMA_SALIDA" "DROP DATABASE TEATRO"

echo
if [[ $FALLOS -eq 0 ]]; then
    printf '\033[32m✓ Instalador verificado con Docker: %d comprobaciones correctas.\033[0m\n' "$TOTAL"
else
    printf '\033[31m✗ %d de %d comprobaciones fallaron.\033[0m\n' "$FALLOS" "$TOTAL"
    exit 1
fi
