#!/usr/bin/env bash
# Instalador de Teatro para Linux con Docker.
#
#   ./instalar.sh          (o sudo ./instalar.sh si su usuario no puede usar Docker)
#
# Menú:
#   1) Instalar con un MySQL nuevo, en Docker: no hace falta nada más.
#   2) Instalar usando un MySQL que ya existe: pide sus credenciales, crea la base
#      TEATRO y un usuario con permisos mínimos para la aplicación.
#   3) Ver el estado.
#   4) Desinstalar.
#
# Guarda la configuración en .env (permisos 600). Volver a ejecutarlo actualiza la
# instalación y conserva los datos, salvo que se elija empezar de cero.

set -euo pipefail
cd "$(dirname "$0")"

PROYECTO="${COMPOSE_PROJECT_NAME:-teatro}"
VOLUMEN="${PROYECTO}_datos-mysql"
IMAGEN_PHP=teatro-php

if [[ -t 1 ]]; then
    NEGRITA=$'\033[1m' VERDE=$'\033[32m' ROJO=$'\033[31m' AMARILLO=$'\033[33m' NORMAL=$'\033[0m'
else
    NEGRITA='' VERDE='' ROJO='' AMARILLO='' NORMAL=''
fi
info()   { printf '%s→%s %s\n' "$NEGRITA" "$NORMAL" "$*"; }
ok()     { printf '%s✓%s %s\n' "$VERDE" "$NORMAL" "$*"; }
aviso()  { printf '%s! %s%s\n' "$AMARILLO" "$*" "$NORMAL" >&2; }
error()  { printf '%s✗ %s%s\n' "$ROJO" "$*" "$NORMAL" >&2; exit 1; }
titulo() { printf '\n%s%s%s\n\n' "$NEGRITA" "$*" "$NORMAL"; }

# -----------------------------------------------------------------------------
# Preguntas
# -----------------------------------------------------------------------------

# preguntar VARIABLE "Pregunta" [valor por defecto]
preguntar() {
    # Nombres locales poco comunes: printf -v escribe en la variable del llamador.
    local _texto="$2" _defecto="${3:-}" _entrada=''
    [[ -n "$_defecto" ]] && _texto+=" [$_defecto]"
    read -r -p "$_texto: " _entrada || [[ -n "$_entrada" ]] || error "Instalación cancelada."
    printf -v "$1" '%s' "${_entrada:-$_defecto}"
}

# preguntar_clave VARIABLE "Pregunta"   (no se muestra lo que se escribe)
preguntar_clave() {
    local _entrada=''
    read -r -s -p "$2: " _entrada || [[ -n "$_entrada" ]] || error "Instalación cancelada."
    [[ -t 0 ]] && echo >&2
    printf -v "$1" '%s' "$_entrada"
}

# confirmar "Pregunta" s|n   (el segundo argumento es la respuesta por defecto)
confirmar() {
    local respuesta opciones='s/N'
    [[ "$2" == s ]] && opciones='S/n'
    while true; do
        preguntar respuesta "$1 ($opciones)" "$2"
        case "${respuesta,,}" in
            s|si|sí|y|yes) return 0 ;;
            n|no)          return 1 ;;
        esac
    done
}

# elegir VARIABLE "Pregunta" OPCIONES_VÁLIDAS POR_DEFECTO   (ej.: elegir op "Opción" "0 1 2" 1)
elegir() {
    local respuesta
    while true; do
        preguntar respuesta "$2" "$4"
        if [[ " $3 " == *" $respuesta "* ]]; then
            printf -v "$1" '%s' "$respuesta"
            return
        fi
        aviso "Escriba una de estas opciones: $3"
    done
}

# -----------------------------------------------------------------------------
# Docker y configuración
# -----------------------------------------------------------------------------

comprobar_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        aviso "Docker no está instalado."
        if [[ $EUID -eq 0 ]] && confirmar "¿Instalarlo ahora con el script oficial de Docker (get.docker.com)?" s; then
            command -v curl >/dev/null 2>&1 || error "Hace falta curl para instalar Docker (apt install curl)."
            curl -fsSL https://get.docker.com | sh
        else
            error "Instale Docker Engine (https://docs.docker.com/engine/install/) o ejecute: sudo ./instalar.sh"
        fi
    fi
    if ! docker info >/dev/null 2>&1; then
        if docker info 2>&1 | grep -qi 'permission denied'; then
            error "Su usuario no tiene permiso para usar Docker. Ejecute: sudo ./instalar.sh"
        fi
        error "Docker no está en ejecución. Inícielo (sudo systemctl start docker) y vuelva a intentar."
    fi
    docker compose version >/dev/null 2>&1 \
        || error "Falta Docker Compose v2 (comando 'docker compose'). Instale el paquete docker-compose-plugin."
}

dc() { docker compose "$@"; }

# valor_env VARIABLE -> valor guardado en .env (vacío si no hay)
valor_env() {
    [[ -f .env ]] || return 0
    sed -n "s/^$1=//p" .env | tail -1 | sed "s/^'\(.*\)'$/\1/"
}

# Escribe .env con permisos 600, de forma atómica. El contenido llega por la entrada estándar.
escribir_env() {
    local temporal
    temporal="$(mktemp .env.XXXXXX)"
    chmod 600 "$temporal"
    cat > "$temporal"
    mv "$temporal" .env
}

clave_aleatoria() { od -An -tx1 -N24 /dev/urandom | tr -d ' \n'; }

volumen_existe() { docker volume inspect "$VOLUMEN" >/dev/null 2>&1; }

describir_modo() {
    case "$(valor_env TEATRO_MODO)" in
        docker) echo "MySQL en Docker" ;;
        socket) echo "MySQL de este servidor ($(valor_env TEATRO_DB_SOCKET_DIR)/$(valor_env TEATRO_DB_SOCKET_ARCHIVO))" ;;
        red)    echo "MySQL en $(valor_env TEATRO_DB_HOST):$(valor_env TEATRO_DB_PORT)" ;;
        *)      echo "configuración manual" ;;
    esac
}

direccion_publica() {
    local puerto ip
    puerto="$(valor_env TEATRO_PUERTO)"
    puerto="${puerto:-8080}"
    if [[ "$puerto" == *:* ]]; then
        echo "http://${puerto}/"
    else
        ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
        echo "http://${ip:-localhost}:${puerto}/"
    fi
}

# La aplicación responde con su página principal (se prueba desde el contenedor de Nginx).
aplicacion_responde() { dc exec -T web wget -q -O /dev/null http://127.0.0.1/ >/dev/null 2>&1; }

detener_instalacion_actual() {
    [[ -f .env ]] || return 0
    info "Deteniendo la instalación actual ($(describir_modo))..."
    dc down --remove-orphans >/dev/null 2>&1 || true
}

# preguntar_puerto -> PUERTO (acepta 8080 o 127.0.0.1:8080)
preguntar_puerto() {
    local actual
    actual="$(valor_env TEATRO_PUERTO)"
    while true; do
        preguntar PUERTO "Puerto web (para usar solo detrás de un proxy con HTTPS: 127.0.0.1:8080)" "${actual:-8080}"
        if [[ ! "$PUERTO" =~ ^([0-9]{1,3}(\.[0-9]{1,3}){3}:)?[0-9]{1,5}$ ]] || (( 10#${PUERTO##*:} < 1 || 10#${PUERTO##*:} > 65535 )); then
            aviso "Escriba un número de puerto (por ejemplo 8080) o IP:puerto (127.0.0.1:8080)."
            continue
        fi
        return
    done
}

comprobar_puerto_libre() {
    command -v ss >/dev/null 2>&1 || return 0
    while ss -Hltn "sport = :${PUERTO##*:}" 2>/dev/null | grep -q .; do
        aviso "El puerto ${PUERTO##*:} ya está en uso por otro programa."
        preguntar_puerto
    done
}

# Valores comunes de .env (límites contra compras masivas): se conservan los actuales.
limites_env() {
    echo "TEATRO_LIMITE_ENTRADAS_COMPRADOR=$(valor_env TEATRO_LIMITE_ENTRADAS_COMPRADOR | grep . || echo 4)"
    echo "TEATRO_LIMITE_COMPRAS_IP=$(valor_env TEATRO_LIMITE_COMPRAS_IP | grep . || echo 20)"
    echo "TEATRO_LIMITE_CONSULTAS_IP=$(valor_env TEATRO_LIMITE_CONSULTAS_IP | grep . || echo 10)"
}

levantar_y_verificar() {
    info "Descargando imágenes y levantando los contenedores (la primera vez tarda unos minutos)..."
    dc up -d --build --remove-orphans
    info "Comprobando que la aplicación responde..."
    for _ in $(seq 1 60); do
        if aplicacion_responde; then
            echo
            ok "${NEGRITA}Teatro está funcionando${NORMAL} ($(describir_modo))."
            echo
            echo "   Dirección:      $(direccion_publica)"
            echo "   Configuración:  .env (permisos 600, contiene las claves)"
            echo "   Estado y logs:  docker compose ps · docker compose logs php"
            echo "   Este menú:      ./instalar.sh"
            echo
            return 0
        fi
        sleep 2
    done
    dc logs --tail 20 php >&2 || true
    error "La aplicación no responde. Revise el detalle de arriba (docker compose logs php)."
}

# -----------------------------------------------------------------------------
# 1) MySQL nuevo en Docker
# -----------------------------------------------------------------------------

instalar_mysql_docker() {
    titulo "Instalación con un MySQL nuevo, en Docker"
    local clave='' borrar_datos=0 opcion ZONA

    if volumen_existe; then
        if [[ "$(valor_env TEATRO_MODO)" == docker && -n "$(valor_env TEATRO_DB_PASSWORD)" ]]; then
            echo "Teatro ya está instalado con MySQL en Docker."
            echo "  1) Actualizar y conservar los datos (las ventas registradas)"
            echo "  2) Empezar de cero: borrar la base y cargar otra vez los datos de ejemplo"
            echo "  0) Cancelar"
            elegir opcion "Opción" "0 1 2" 1
            case "$opcion" in
                0) exit 0 ;;
                1) clave="$(valor_env TEATRO_DB_PASSWORD)" ;;
                2) borrar_datos=1 ;;
            esac
        else
            aviso "Hay datos de MySQL de una instalación anterior (volumen $VOLUMEN) sin su configuración."
            confirmar "¿Borrarlos y crear la base de cero?" n || error "Instalación cancelada: no se tocó nada."
            borrar_datos=1
        fi
    fi

    preguntar_puerto
    while true; do
        preguntar ZONA "Zona horaria de MySQL, decide qué obras ya pasaron (ej.: -06:00, -05:00, +01:00)" \
            "$(valor_env TEATRO_ZONA_HORARIA | grep . || echo -06:00)"
        [[ "$ZONA" =~ ^[+-][0-9]{2}:[0-9]{2}$ ]] && break
        aviso "Use el formato ±HH:MM, por ejemplo -06:00."
    done

    detener_instalacion_actual
    if (( borrar_datos )); then
        info "Borrando los datos anteriores..."
        docker volume rm "$VOLUMEN" >/dev/null
    fi
    comprobar_puerto_libre

    escribir_env <<EOF
# Generado por ./instalar.sh: MySQL nuevo en Docker. Contiene claves: no lo comparta.
COMPOSE_FILE=docker-compose.yml:docker/mysql-docker.yml
TEATRO_MODO=docker
TEATRO_PUERTO=$PUERTO
TEATRO_ZONA_HORARIA=$ZONA
TEATRO_DB_PASSWORD=${clave:-$(clave_aleatoria)}
$(limites_env)
EOF
    levantar_y_verificar
}

# -----------------------------------------------------------------------------
# 2) MySQL que ya existe
# -----------------------------------------------------------------------------

# Ejecuta una tarea de docker/instalar-bd.php con la conexión de las variables BD_*.
bd() {
    local argumentos=(--rm --add-host host.docker.internal:host-gateway
        -v "$PWD/docker/instalar-bd.php:/instalar-bd.php:ro"
        -v "$PWD/database/teatro.sql:/teatro.sql:ro"
        -e BD_HOST -e BD_PORT -e BD_SOCKET -e BD_USER -e BD_PASSWORD -e APP_USER -e APP_HOST -e APP_PASSWORD)
    [[ -n "$SOCKET_DIR" ]] && argumentos+=(-v "$SOCKET_DIR:/run/mysqld-servidor:ro")
    docker run "${argumentos[@]}" "$IMAGEN_PHP" php /instalar-bd.php "$1"
}

socket_detectado() {
    local s
    for s in /var/run/mysqld/mysqld.sock /run/mysqld/mysqld.sock /var/lib/mysql/mysql.sock /tmp/mysql.sock; do
        [[ -S "$s" ]] && { echo "$s"; return 0; }
    done
    return 0
}

# Avisa si la versión no aplica las restricciones CHECK de la base (MySQL < 8.0.16, MariaDB < 10.3).
comprobar_version() {
    local version="$1" mayor menor parche
    IFS=. read -r mayor menor parche <<< "${version%%-*}"
    parche="${parche%%[!0-9]*}"
    if [[ "$version" == *MariaDB* ]]; then
        (( mayor > 10 || (mayor == 10 && menor >= 3) )) && return 0
    else
        (( mayor > 8 || (mayor == 8 && (menor > 0 || ${parche:-0} >= 16)) )) && return 0
    fi
    aviso "Su servidor ($version) es anterior a MySQL 8.0.16 / MariaDB 10.3 y no aplica las restricciones CHECK de la base."
    confirmar "¿Continuar de todos modos?" n || error "Instalación cancelada: no se tocó nada."
}

instalar_mysql_existente() {
    titulo "Instalación usando un MySQL que ya existe"
    local donde socket version tablas opcion app_host
    SOCKET_DIR=''
    export BD_HOST='' BD_PORT='' BD_SOCKET='' BD_USER='' BD_PASSWORD='' APP_USER='' APP_HOST='' APP_PASSWORD=''

    socket="$(socket_detectado)"
    echo "¿Dónde está MySQL?"
    echo "  1) Instalado en este mismo servidor (se conecta por su socket, sin abrirlo a la red)"
    echo "  2) En otro servidor, o publicado en un puerto (por IP o nombre y puerto)"
    [[ -n "$socket" ]] && echo "     Se detectó un MySQL en este servidor: $socket"
    elegir donde "Opción" "1 2" "$([[ -n "$socket" ]] && echo 1 || echo 2)"

    if [[ "$donde" == 1 ]]; then
        while true; do
            preguntar socket "Ruta del socket de MySQL" "$socket"
            [[ -S "$socket" ]] && break
            aviso "$socket no es un socket de MySQL. Búsquelo con: mysqladmin variables | grep socket"
        done
        SOCKET_DIR="$(dirname "$socket")"
        BD_SOCKET="/run/mysqld-servidor/$(basename "$socket")"
        app_host=localhost
    else
        preguntar BD_HOST "Servidor de MySQL (IP o nombre)" "${BD_HOST:-}"
        [[ -n "$BD_HOST" ]] || error "Hace falta el servidor de MySQL."
        preguntar BD_PORT "Puerto" 3306
        if [[ "$BD_HOST" =~ ^(localhost|127\.0\.0\.1|::1)$ ]]; then
            # Dentro de un contenedor, localhost es el propio contenedor.
            info "Se usará host.docker.internal, que dentro de Docker apunta a este servidor."
            BD_HOST=host.docker.internal
        fi
        app_host='%'
    fi

    info "Preparando la imagen de PHP..."
    docker build -q -t "$IMAGEN_PHP" ./docker >/dev/null

    echo
    echo "Credenciales de un usuario de MySQL que pueda crear bases y usuarios (por ejemplo root)."
    echo "Se usan solo durante la instalación y no se guardan, salvo que lo pida más adelante."
    for intento in 1 2 3; do
        preguntar BD_USER "Usuario" "${BD_USER:-root}"
        preguntar_clave BD_PASSWORD "Contraseña (Enter si no tiene)"
        if version="$(bd probar 2>&1)"; then
            ok "Conectado a MySQL $version"
            break
        fi
        aviso "No se pudo conectar: $version"
        (( intento == 3 )) && error "Revise el servidor y las credenciales y vuelva a ejecutar ./instalar.sh"
    done
    comprobar_version "$version"

    tablas="$(bd tablas)"
    opcion=2
    if [[ "$tablas" == 2 ]]; then
        echo
        echo "La base TEATRO ya existe en ese MySQL."
        echo "  1) Conservarla con sus datos"
        echo "  2) Reemplazarla por los datos de ejemplo (borra las ventas registradas)"
        echo "  0) Cancelar"
        elegir opcion "Opción" "0 1 2" 1
        [[ "$opcion" == 0 ]] && exit 0
    elif [[ "$tablas" == 1 ]]; then
        aviso "La base TEATRO existe, pero incompleta: se volverá a importar."
        confirmar "¿Continuar?" s || error "Instalación cancelada: no se tocó nada."
    fi
    if [[ "$opcion" == 2 ]]; then
        info "Importando database/teatro.sql en la base TEATRO..."
        bd importar >/dev/null
        ok "Base TEATRO importada con los datos de ejemplo."
    fi

    echo
    APP_USER=teatro_app APP_HOST="$app_host" APP_PASSWORD="$(clave_aleatoria)"
    if confirmar "¿Crear el usuario teatro_app, solo con los permisos que la aplicación necesita? (recomendado)" s; then
        local resultado
        if resultado="$(bd crear-usuario 2>&1)"; then
            ok "Usuario 'teatro_app'@'$app_host' listo (SELECT, INSERT, UPDATE y DELETE sobre TEATRO)."
        else
            aviso "No se pudo crear el usuario: $resultado"
            APP_USER=''
        fi
    else
        APP_USER=''
    fi
    if [[ -z "$APP_USER" ]]; then
        confirmar "¿Usar el usuario $BD_USER para la aplicación? Su contraseña quedará en .env" n \
            || error "Instalación cancelada. Cree un usuario para la aplicación y vuelva a ejecutar ./instalar.sh"
        [[ "$BD_PASSWORD" != *"'"* ]] || error "La contraseña contiene comillas simples ('), que .env no admite. Cree el usuario teatro_app."
        APP_USER="$BD_USER" APP_PASSWORD="$BD_PASSWORD"
    fi

    # Prueba final con las credenciales que usará la aplicación.
    local verificacion
    verificacion="$(BD_USER="$APP_USER" BD_PASSWORD="$APP_PASSWORD" bd verificar 2>&1)" \
        || error "La aplicación no puede leer la base TEATRO con el usuario $APP_USER: $verificacion"
    ok "La aplicación puede usar la base TEATRO ($verificacion)."

    echo
    preguntar_puerto
    if [[ "$(valor_env TEATRO_MODO)" == docker ]] && volumen_existe; then
        aviso "Los datos del MySQL en Docker anterior se conservan en el volumen $VOLUMEN (docker volume rm $VOLUMEN para borrarlos)."
    fi
    detener_instalacion_actual
    comprobar_puerto_libre

    if [[ "$donde" == 1 ]]; then
        escribir_env <<EOF
# Generado por ./instalar.sh: MySQL de este servidor, por socket. Contiene claves: no lo comparta.
COMPOSE_FILE=docker-compose.yml:docker/mysql-socket.yml
TEATRO_MODO=socket
TEATRO_PUERTO=$PUERTO
TEATRO_DB_SOCKET_DIR='$SOCKET_DIR'
TEATRO_DB_SOCKET_ARCHIVO='$(basename "$socket")'
TEATRO_DB_USER='$APP_USER'
TEATRO_DB_PASSWORD='$APP_PASSWORD'
$(limites_env)
EOF
    else
        escribir_env <<EOF
# Generado por ./instalar.sh: MySQL en otro servidor. Contiene claves: no lo comparta.
COMPOSE_FILE=docker-compose.yml
TEATRO_MODO=red
TEATRO_PUERTO=$PUERTO
TEATRO_DB_HOST='$BD_HOST'
TEATRO_DB_PORT=$BD_PORT
TEATRO_DB_USER='$APP_USER'
TEATRO_DB_PASSWORD='$APP_PASSWORD'
$(limites_env)
EOF
    fi
    levantar_y_verificar
}

# -----------------------------------------------------------------------------
# 3) Estado y 4) Desinstalar
# -----------------------------------------------------------------------------

ver_estado() {
    titulo "Estado de Teatro"
    [[ -f .env ]] || { echo "Teatro no está instalado. Ejecute ./instalar.sh y elija 1 o 2."; return; }
    echo "Modo:       $(describir_modo)"
    echo "Dirección:  $(direccion_publica)"
    echo
    dc ps --format 'table {{.Service}}\t{{.Status}}'
    echo
    if aplicacion_responde; then ok "La aplicación responde."; else aviso "La aplicación no responde. Revise: docker compose logs php"; fi
}

desinstalar() {
    titulo "Desinstalar Teatro"
    [[ -f .env ]] || volumen_existe || { echo "Teatro no está instalado."; return; }
    confirmar "¿Detener y eliminar los contenedores de Teatro?" n || return 0

    local modo
    modo="$(valor_env TEATRO_MODO)"
    detener_instalacion_actual
    if volumen_existe; then
        if confirmar "¿Borrar también la base de datos de MySQL en Docker (obras y ventas registradas)?" n; then
            docker volume rm "$VOLUMEN" >/dev/null
            ok "Base de datos borrada."
        else
            # Se conserva .env: tiene la clave con la que se creó esa base.
            ok "Contenedores eliminados. Los datos y .env se conservan: ./instalar.sh, opción 1, los vuelve a usar."
            return
        fi
    fi
    rm -f .env
    docker image rm "$IMAGEN_PHP" >/dev/null 2>&1 || true
    ok "Teatro desinstalado."
    if [[ "$modo" == socket || "$modo" == red ]]; then
        echo "  La base TEATRO y el usuario teatro_app siguen en su MySQL. Para borrarlos:"
        echo "  DROP DATABASE TEATRO; DROP USER 'teatro_app'@'$([[ "$modo" == socket ]] && echo localhost || echo %)';"
    fi
}

# -----------------------------------------------------------------------------
# Menú
# -----------------------------------------------------------------------------

titulo "Teatro · Instalación con Docker"
comprobar_docker

if [[ -f .env ]]; then
    echo "Instalación actual: $(describir_modo) en $(direccion_publica)"
    echo
fi
if [[ -n "$(socket_detectado)" ]]; then
    echo "Se detectó un MySQL instalado en este servidor: puede usarlo con la opción 2."
    echo
fi
echo "  1) Instalar con un MySQL nuevo, en Docker (recomendado: no necesita nada más)"
echo "  2) Instalar usando un MySQL que ya existe (pide sus credenciales)"
echo "  3) Ver el estado"
echo "  4) Desinstalar"
echo "  0) Salir"
elegir OPCION "Opción" "0 1 2 3 4" "$([[ -f .env ]] && echo 3 || echo 1)"

case "$OPCION" in
    1) instalar_mysql_docker ;;
    2) instalar_mysql_existente ;;
    3) ver_estado ;;
    4) desinstalar ;;
    0) exit 0 ;;
esac
