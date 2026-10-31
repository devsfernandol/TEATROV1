#!/usr/bin/env bash
# Pruebas de punta a punta contra el entorno de desarrollo.
# Requiere que dev/iniciar.sh esté corriendo. Restaura la base al empezar y al terminar.
#
# Uso: dev/pruebas.sh [URL_BASE]     (por defecto http://localhost:8000)

set -uo pipefail
source "$(dirname "$0")/entorno.sh"

BASE="${1:-http://localhost:$PHP_PUERTO}"
# Log de PHP a revisar (dev/prueba-instalacion.sh lo cambia para su servidor).
PHP_LOG="${PRUEBAS_PHP_LOG:-$PHP_LOG}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FALLOS=0
TOTAL=0

ok()    { TOTAL=$((TOTAL + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
falla() { TOTAL=$((TOTAL + 1)); FALLOS=$((FALLOS + 1)); printf '  \033[31m✗ %s\033[0m\n    %s\n' "$1" "$2"; }

# igual "descripción" "obtenido" "esperado"
igual() {
    if [[ "$2" == "$3" ]]; then ok "$1"; else falla "$1" "esperado: '$3' · obtenido: '$2'"; fi
}

# contiene "descripción" "archivo" "texto"
contiene() {
    if grep -qF -- "$3" "$2"; then ok "$1"; else falla "$1" "no se encontró: '$3'"; fi
}

# no_contiene "descripción" "archivo" "texto"
no_contiene() {
    if grep -qF -- "$3" "$2"; then falla "$1" "se encontró: '$3'"; else ok "$1"; fi
}

sql() { mysql_root -N -B TEATRO -e "$1"; }

# codigo URL [opciones curl...] -> imprime el código HTTP
codigo() { local url="$1"; shift; curl -s -o /dev/null -w '%{http_code}' "$@" "$url"; }

# token_de ARCHIVO_COOKIES COD_OBRA -> imprime el token del formulario de compra
token_de() {
    curl -s -c "$1" -b "$1" "$BASE/comprar.php?obra=$2" \
        | grep -oE 'name="token" value="[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}'
}

mysql_activo || { echo "✗ MySQL de desarrollo no está activo. Ejecute dev/iniciar.sh" >&2; exit 1; }
curl -s -o /dev/null "$BASE/" || { echo "✗ La aplicación no responde en $BASE. Ejecute dev/iniciar.sh" >&2; exit 1; }

"$(dirname "$0")/reiniciar-bd.sh" >/dev/null
: > "$PHP_LOG"

# -----------------------------------------------------------------------------
echo "Página de obras disponibles (index)"
igual "index.php responde 200" "$(codigo "$BASE/index.php")" "200"
igual "La raíz del sitio carga index.php" "$(codigo "$BASE/")" "200"
curl -s "$BASE/index.php" > "$TMP/index.html"
igual "Muestra las 5 obras disponibles" "$(grep -c 'class="tarjeta obra"' "$TMP/index.html")" "5"
no_contiene "No muestra la obra agotada (Luces de bohemia)" "$TMP/index.html" "Luces de bohemia"
no_contiene "No muestra la obra con fecha pasada (Fuenteovejuna)" "$TMP/index.html" "Fuenteovejuna"
contiene "Enlaza a la compra de cada obra" "$TMP/index.html" 'comprar.php?obra=1'
contiene "Enlaza a «Consultar mi entrada»" "$TMP/index.html" 'consultar.php'
igual "Las obras se ordenan por fecha (primera: la más próxima)" \
    "$(grep -oE 'obra__nombre">[^<]+' "$TMP/index.html" | head -1 | cut -d'>' -f2)" "La casa de Bernarda Alba"
contiene "Muestra las entradas disponibles de cada obra" "$TMP/index.html" "<dd>78 de 80</dd>"
contiene "Muestra la sala" "$TMP/index.html" "Sala Lorca"
contiene "Muestra la fecha en español" "$TMP/index.html" " h</time>"
contiene "Los acentos se muestran correctamente (UTF-8)" "$TMP/index.html" "El sí de las niñas"

# -----------------------------------------------------------------------------
echo "Seguridad: cabeceras HTTP y cookie de sesión"
curl -s -D "$TMP/cabeceras.txt" -o /dev/null "$BASE/index.php"
contiene "Content-Type HTML en UTF-8" "$TMP/cabeceras.txt" "Content-Type: text/html; charset=utf-8"
contiene "Content-Security-Policy restrictiva" "$TMP/cabeceras.txt" "Content-Security-Policy: default-src 'self'"
contiene "X-Frame-Options: DENY (anti clickjacking)" "$TMP/cabeceras.txt" "X-Frame-Options: DENY"
contiene "X-Content-Type-Options: nosniff" "$TMP/cabeceras.txt" "X-Content-Type-Options: nosniff"
contiene "Sin caché (la disponibilidad cambia en tiempo real)" "$TMP/cabeceras.txt" "Cache-Control: no-store"
contiene "Cookie de sesión HttpOnly" "$TMP/cabeceras.txt" "HttpOnly"
contiene "Cookie de sesión SameSite=Lax" "$TMP/cabeceras.txt" "SameSite=Lax"
no_contiene "No expone la versión de PHP (X-Powered-By)" "$TMP/cabeceras.txt" "X-Powered-By: PHP"
igual "Por HTTP la cookie de sesión no se marca Secure" "$(grep -i '^set-cookie' "$TMP/cabeceras.txt" | grep -ci 'secure')" "0"
curl -s -D "$TMP/cabeceras-proxy.txt" -o /dev/null -H 'X-Forwarded-Proto: https' "$BASE/index.php"
igual "Detrás de un proxy HTTPS (X-Forwarded-Proto) la cookie se marca Secure" \
    "$(grep -i '^set-cookie' "$TMP/cabeceras-proxy.txt" | grep -ci 'secure')" "1"
curl -s -D "$TMP/cabeceras-proxy.txt" -o /dev/null -H 'Forwarded: for=203.0.113.5;proto=https' "$BASE/index.php"
igual "Detrás de un proxy HTTPS (Forwarded) la cookie se marca Secure" \
    "$(grep -i '^set-cookie' "$TMP/cabeceras-proxy.txt" | grep -ci 'secure')" "1"
for pagina in index.php "comprar.php?obra=1" "comprar.php?obra=999"; do
    curl -s "$BASE/$pagina" > "$TMP/pagina.html"
    contiene "$pagina: HTML en español con charset UTF-8" "$TMP/pagina.html" '<html lang="es">'
    contiene "$pagina: carga la hoja de estilos" "$TMP/pagina.html" 'assets/css/estilos.css'
done
igual "La hoja de estilos se sirve (200)" "$(codigo "$BASE/assets/css/estilos.css")" "200"
no_contiene "No carga JavaScript (solo PHP, HTML y CSS)" "$TMP/pagina.html" "<script"
contiene "La política de seguridad prohíbe ejecutar scripts" "$TMP/cabeceras.txt" "script-src 'none'"

# -----------------------------------------------------------------------------
echo "Parámetros inválidos y URLs inesperadas"
for q in "" "obra=" "obra=abc" "obra=-1" "obra=0" "obra=1.5" "obra=6" "obra=7" "obra=999" "obra%5B%5D=1" "obra=99999999999999999999" "obra=1%27%20OR%201=1"; do
    igual "comprar.php?$q responde 404" "$(codigo "$BASE/comprar.php?$q")" "404"
done
igual "comprar.php/extra (PATH_INFO) responde 404" "$(codigo "$BASE/comprar.php/extra")" "404"
igual "confirmacion.php sin venta responde 404" "$(codigo "$BASE/confirmacion.php")" "404"

# -----------------------------------------------------------------------------
echo "Validación del identificador"
C="$TMP/c1.txt"
T=$(token_de "$C" 1)
igual "El formulario incluye un token" "${#T}" "64"
igual "Identificador vacío responde 422" "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token=$T&identificador=")" "422"
for malo in "ab" "1234" "<script>alert(1)</script>" "-12345" "12345-" "ÑANDÚ12345" "123456789012345678901"; do
    igual "Identificador '$malo' responde 422" \
        "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" --data-urlencode "token=$T" --data-urlencode "identificador=$malo")" "422"
done
curl -s -c "$C" -b "$C" --data-urlencode "token=$T" --data-urlencode 'identificador=<script>alert(1)</script>' \
    "$BASE/comprar.php?obra=1" > "$TMP/xss.html"
no_contiene "El valor ingresado se escapa (sin XSS)" "$TMP/xss.html" "<script>alert(1)"
contiene "El valor ingresado se conserva escapado" "$TMP/xss.html" "&lt;script&gt;"
LARGO=$(head -c 20000 /dev/zero | tr '\0' 'A')
igual "Identificador de 20 000 caracteres responde 422 (sin caerse)" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token=$T&identificador=$LARGO")" "422"
igual "Bytes no UTF-8 en el identificador responden 422" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token=$T&identificador=%FF%FE%00abc")" "422"
igual "Identificador enviado como arreglo responde 422" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token=$T&identificador[]=V12345678")" "422"
igual "Inyección SQL en el identificador responde 422" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" --data-urlencode "token=$T" --data-urlencode "identificador=1' OR '1'='1")" "422"
igual "Token enviado como arreglo responde 400" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token[]=$T&identificador=V12345678")" "400"
igual "Ninguna venta registrada por entradas inválidas" "$(sql 'SELECT COUNT(*) FROM VENTAS')" "10"
igual "Las tablas siguen intactas" "$(sql 'SELECT COUNT(*) FROM OBRA')" "7"

# -----------------------------------------------------------------------------
echo "Token del formulario (CSRF) y cookies"
igual "Token falso responde 400" "$(codigo "$BASE/comprar.php?obra=1" -c "$C" -b "$C" -d "token=abc&identificador=V12345678")" "400"
curl -s -c "$C" -b "$C" -d "token=abc&identificador=V12345678" "$BASE/comprar.php?obra=1" > "$TMP/expirado.html"
contiene "Con cookies: avisa que la sesión expiró" "$TMP/expirado.html" "Su sesión expiró"
contiene "Conserva el identificador ingresado" "$TMP/expirado.html" 'value="V12345678"'
curl -s -d "token=$T&identificador=V12345678" "$BASE/comprar.php?obra=1" > "$TMP/sincookies.html"
contiene "Sin cookies: pide habilitarlas" "$TMP/sincookies.html" "no está aceptando cookies"
igual "Ninguna venta registrada sin token válido" "$(sql 'SELECT COUNT(*) FROM VENTAS')" "10"

# -----------------------------------------------------------------------------
echo "Compra exitosa"
DISP_ANTES=$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 1')
RESP=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -c "$C" -b "$C" \
    -d "token=$T&identificador=v-12.345.678" "$BASE/comprar.php?obra=1")
igual "Redirige (303) a la confirmación de la venta 11" "$RESP" "303 $BASE/confirmacion.php?venta=11"
igual "VENTAS: se registró la venta 11 de la obra 1" "$(sql 'SELECT CONCAT(numero_venta, "|", cod_obra) FROM VENTAS WHERE numero_venta = 11')" "11|1"
igual "VENTAS: el identificador se guardó normalizado" "$(sql 'SELECT comprador FROM VENTAS WHERE numero_venta = 11')" "V-12345678"
igual "VENTAS: fecha_compra registrada" "$(sql 'SELECT fecha_compra IS NOT NULL AND fecha_compra <= NOW() FROM VENTAS WHERE numero_venta = 11')" "1"
igual "OBRA: disponibles bajó en uno" "$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 1')" "$((DISP_ANTES - 1))"

curl -s -b "$C" "$BASE/confirmacion.php?venta=11" > "$TMP/conf.html"
contiene "La confirmación muestra el número de entrada" "$TMP/conf.html" 'entrada__numero-valor">11<'
contiene "La confirmación muestra la obra" "$TMP/conf.html" "La casa de Bernarda Alba"
contiene "La confirmación muestra el comprador" "$TMP/conf.html" "V-12345678"
igual "Refrescar la confirmación responde 200" "$(codigo "$BASE/confirmacion.php?venta=11" -b "$C")" "200"

# -----------------------------------------------------------------------------
echo "Doble envío y privacidad"
RESP=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -c "$C" -b "$C" \
    -d "token=$T&identificador=V99999999" "$BASE/comprar.php?obra=1")
igual "Reenviar el mismo formulario lleva a la misma venta" "$RESP" "303 $BASE/confirmacion.php?venta=11"
igual "Reenviar no genera otra venta" "$(sql 'SELECT COUNT(*) FROM VENTAS')" "11"
igual "Reenviar no descuenta otra entrada" "$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 1')" "$((DISP_ANTES - 1))"
igual "Otra sesión no puede ver la entrada 11" "$(codigo "$BASE/confirmacion.php?venta=11")" "404"
igual "No se pueden ver entradas ajenas (venta 1)" "$(codigo "$BASE/confirmacion.php?venta=1" -b "$C")" "404"
curl -s "$BASE/confirmacion.php?venta=11" > "$TMP/ajena.html"
contiene "La entrada no encontrada indica cómo recuperarla" "$TMP/ajena.html" "Consultar mi entrada"

# -----------------------------------------------------------------------------
echo "Consultar mi entrada (recuperarla desde otro navegador)"
CQ="$TMP/consulta.txt"
igual "consultar.php responde 200" "$(codigo "$BASE/consultar.php" -c "$CQ" -b "$CQ")" "200"
curl -s -b "$CQ" "$BASE/consultar.php" > "$TMP/consulta.html"
contiene "Pide el número de entrada" "$TMP/consulta.html" 'name="numero"'
contiene "Pide el identificador" "$TMP/consulta.html" 'name="identificador"'
RESP=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -c "$CQ" -b "$CQ" \
    -d "numero=11&identificador=v-12.345.678" "$BASE/consultar.php")
igual "Con número e identificador correctos lleva a la entrada 11" "$RESP" "303 $BASE/confirmacion.php?venta=11"
curl -s -b "$CQ" "$BASE/confirmacion.php?venta=11" > "$TMP/recuperada.html"
contiene "La entrada recuperada muestra su número" "$TMP/recuperada.html" 'entrada__numero-valor">11<'
contiene "La entrada recuperada muestra la obra" "$TMP/recuperada.html" "La casa de Bernarda Alba"

CQ2="$TMP/consulta2.txt"
codigo "$BASE/consultar.php" -c "$CQ2" -b "$CQ2" >/dev/null
igual "Identificador que no corresponde a la entrada responde 404" \
    "$(codigo "$BASE/consultar.php" -c "$CQ2" -b "$CQ2" -d "numero=11&identificador=V99999999")" "404"
igual "y no da acceso a la entrada" "$(codigo "$BASE/confirmacion.php?venta=11" -b "$CQ2")" "404"
curl -s -c "$CQ2" -b "$CQ2" -d "numero=11&identificador=V99999999" "$BASE/consultar.php" > "$TMP/consulta-mal.html"
contiene "Explica que no encontró la entrada" "$TMP/consulta-mal.html" "No encontramos una entrada con ese número e identificador"
igual "Entrada inexistente responde 404" "$(codigo "$BASE/consultar.php" -c "$CQ2" -b "$CQ2" -d "numero=999&identificador=V12345678")" "404"
for q in "numero=&identificador=V12345678" "numero=abc&identificador=V12345678" "numero=11&identificador=ab" "numero[]=11&identificador=V12345678"; do
    igual "Datos inválidos ($q) responden 422" "$(codigo "$BASE/consultar.php" -c "$CQ2" -b "$CQ2" -d "$q")" "422"
done
curl -s -c "$CQ2" -b "$CQ2" --data-urlencode 'numero=<script>' -d 'identificador=V12345678' "$BASE/consultar.php" > "$TMP/consulta-xss.html"
no_contiene "El número ingresado se escapa (sin XSS)" "$TMP/consulta-xss.html" "<script>"
igual "Sin cookies responde 400" "$(codigo "$BASE/consultar.php" -d "numero=11&identificador=V-12345678")" "400"
igual "Consultar no registra ventas" "$(sql 'SELECT COUNT(*) FROM VENTAS')" "11"

# -----------------------------------------------------------------------------
echo "Identificadores válidos en los límites"
for valido in "ABCDE" "A1234567890123456789" "e-12345678" "  p 1234.567  "; do
    CV="$TMP/valido.txt"
    TV=$(token_de "$CV" 5)
    igual "Identificador '$valido' se acepta" \
        "$(codigo "$BASE/comprar.php?obra=5" -c "$CV" -b "$CV" --data-urlencode "token=$TV" --data-urlencode "identificador=$valido")" "303"
done
igual "Se guardan normalizados (mayúsculas, sin espacios ni puntos)" \
    "$(sql "SELECT GROUP_CONCAT(comprador ORDER BY numero_venta SEPARATOR ',') FROM VENTAS WHERE cod_obra = 5")" \
    "ABCDE,A1234567890123456789,E-12345678,P1234567"

# -----------------------------------------------------------------------------
echo "Obra que deja de estar disponible mientras se compra"
C2="$TMP/c2.txt"
T2=$(token_de "$C2" 4)
sql 'UPDATE OBRA SET fecha_obra = NOW() - INTERVAL 1 MINUTE WHERE cod_obra = 4'
igual "Si la fecha ya pasó, responde 409" "$(codigo "$BASE/comprar.php?obra=4" -c "$C2" -b "$C2" -d "token=$T2&identificador=V12345678")" "409"
igual "No se registró la venta" "$(sql 'SELECT COUNT(*) FROM VENTAS WHERE cod_obra = 4')" "0"
igual "No se descontó la entrada" "$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 4')" "200"

# -----------------------------------------------------------------------------
echo "Concurrencia: 20 compras simultáneas por las 2 últimas entradas"
for i in $(seq 1 20); do
    token_de "$TMP/s$i.txt" 3 > "$TMP/t$i.txt"
done
for i in $(seq 1 20); do
    curl -s -o /dev/null -w '%{http_code}\n' -b "$TMP/s$i.txt" -c "$TMP/s$i.txt" \
        -d "token=$(cat "$TMP/t$i.txt")&identificador=V100000$i" "$BASE/comprar.php?obra=3" > "$TMP/r$i.txt" &
done
wait
igual "Exactamente 2 compras exitosas" "$(cat "$TMP"/r*.txt | grep -c '^303$')" "2"
igual "Las otras 18 se rechazan con 409" "$(cat "$TMP"/r*.txt | grep -c '^409$')" "18"
igual "OBRA: disponibles quedó en 0 (sin negativos)" "$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 3')" "0"
igual "VENTAS: hay exactamente tantas ventas como aforo" "$(sql 'SELECT COUNT(*) FROM VENTAS WHERE cod_obra = 3')" "5"
curl -s "$BASE/index.php" > "$TMP/index2.html"
no_contiene "La obra agotada desaparece de la lista" "$TMP/index2.html" "La vida es sueño"

# -----------------------------------------------------------------------------
echo "Mismo usuario comprando al mismo tiempo"
VENTAS_ANTES=$(sql 'SELECT COUNT(*) FROM VENTAS')
DISP_ANTES=$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 2')

# Doble clic real: el mismo formulario enviado 10 veces en paralelo.
CM="$TMP/mismo.txt"
TM=$(token_de "$CM" 2)
for i in $(seq 1 10); do
    curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' -b "$CM" \
        -d "token=$TM&identificador=V55555555" "$BASE/comprar.php?obra=2" > "$TMP/doble$i.txt" &
done
wait
igual "Mismo formulario enviado 10 veces a la vez: todas llevan a la misma venta" \
    "$(cat "$TMP"/doble*.txt | sort -u | wc -l | tr -d ' ')" "1"
igual "Mismo formulario enviado 10 veces a la vez: se registra 1 sola venta" \
    "$(sql 'SELECT COUNT(*) FROM VENTAS')" "$((VENTAS_ANTES + 1))"
igual "Mismo formulario enviado 10 veces a la vez: se descuenta 1 sola entrada" \
    "$(sql 'SELECT disponibles FROM OBRA WHERE cod_obra = 2')" "$((DISP_ANTES - 1))"

# Mismo navegador con dos pestañas: son dos compras distintas e intencionales.
TA=$(token_de "$CM" 2)
TB=$(token_de "$CM" 2)
curl -s -o /dev/null -w '%{redirect_url}\n' -b "$CM" -d "token=$TA&identificador=V55555555" "$BASE/comprar.php?obra=2" > "$TMP/pa.txt" &
curl -s -o /dev/null -w '%{redirect_url}\n' -b "$CM" -d "token=$TB&identificador=V55555555" "$BASE/comprar.php?obra=2" > "$TMP/pb.txt" &
wait
if [[ "$(cat "$TMP/pa.txt")" != "$(cat "$TMP/pb.txt")" ]]; then
    ok "Dos pestañas a la vez: cada una obtiene su propio número de entrada"
else
    falla "Dos pestañas a la vez: cada una obtiene su propio número de entrada" "ambas: $(cat "$TMP/pa.txt")"
fi
igual "Dos pestañas a la vez: se registran exactamente 2 ventas más" \
    "$(sql 'SELECT COUNT(*) FROM VENTAS')" "$((VENTAS_ANTES + 3))"

# Mismo identificador desde 5 navegadores distintos a la vez.
for i in $(seq 1 5); do token_de "$TMP/n$i.txt" 2 > "$TMP/nt$i.txt"; done
for i in $(seq 1 5); do
    curl -s -o /dev/null -w '%{http_code}\n' -b "$TMP/n$i.txt" \
        -d "token=$(cat "$TMP/nt$i.txt")&identificador=V77777777" "$BASE/comprar.php?obra=2" > "$TMP/nr$i.txt" &
done
wait
igual "Mismo identificador desde 5 navegadores a la vez: solo 4 compras (máximo por persona)" "$(cat "$TMP"/nr*.txt | grep -c '^303$')" "4"
igual "Mismo identificador desde 5 navegadores a la vez: la quinta se rechaza con 422" "$(cat "$TMP"/nr*.txt | grep -c '^422$')" "1"
igual "VENTAS: ese identificador tiene exactamente 4 entradas de la obra" \
    "$(sql "SELECT COUNT(*) FROM VENTAS WHERE cod_obra = 2 AND comprador = 'V77777777'")" "4"
CL="$TMP/limite.txt"
TL=$(token_de "$CL" 2)
curl -s -c "$CL" -b "$CL" -d "token=$TL&identificador=V77777777" "$BASE/comprar.php?obra=2" > "$TMP/limite.html"
contiene "Explica el máximo de entradas por persona" "$TMP/limite.html" "ya tiene el máximo de 4 entradas"
igual "El mismo identificador puede comprar para otra obra" \
    "$(codigo "$BASE/comprar.php?obra=1" -c "$CL" -b "$CL" -d "token=$(token_de "$CL" 1)&identificador=V77777777")" "303"
igual "Mismo identificador desde 5 navegadores a la vez: números de entrada sin repetir" \
    "$(sql 'SELECT COUNT(DISTINCT numero_venta) = COUNT(*) FROM VENTAS')" "1"

# -----------------------------------------------------------------------------
echo "Base de datos bloqueada momentáneamente (alta carga)"
# Se reduce el tiempo de espera de bloqueos a 1 s y otra transacción retiene la
# fila de la obra durante 2 s: el primer intento expira y la compra debe reintentarse sola.
CB="$TMP/bloqueo.txt"
TBQ=$(token_de "$CB" 5)
sql 'SET GLOBAL innodb_lock_wait_timeout = 1'
mysql_root TEATRO -e 'START TRANSACTION; SELECT cod_obra FROM OBRA WHERE cod_obra = 5 FOR UPDATE; SELECT SLEEP(2); COMMIT;' >/dev/null &
BLOQUEO=$!
sleep 0.3
igual "La compra se completa pese al bloqueo (reintento automático)" \
    "$(codigo "$BASE/comprar.php?obra=5" -b "$CB" -d "token=$TBQ&identificador=V88888888")" "303"
wait "$BLOQUEO"
sql 'SET GLOBAL innodb_lock_wait_timeout = 50'
igual "Se registró una sola venta para esa compra" "$(sql "SELECT COUNT(*) FROM VENTAS WHERE comprador = 'V88888888'")" "1"
if grep -q 'Reintento 1 de la compra por bloqueo' "$PHP_LOG" 2>/dev/null; then
    ok "El reintento quedó registrado en el log"
else
    falla "El reintento quedó registrado en el log" "no se encontró en $PHP_LOG"
fi

# -----------------------------------------------------------------------------
echo "Integridad de los datos"
igual "Para toda obra: disponibles = aforo - ventas" \
    "$(sql 'SELECT COUNT(*) FROM OBRA o WHERE o.disponibles <> o.aforo - (SELECT COUNT(*) FROM VENTAS v WHERE v.cod_obra = o.cod_obra)')" "0"
igual "Los números de venta son correlativos" "$(sql 'SELECT MAX(numero_venta) = COUNT(*) FROM VENTAS')" "1"

# -----------------------------------------------------------------------------
echo "Errores de PHP"
if grep -qE 'PHP (Warning|Notice|Fatal|Parse|Deprecated)|\[TEATRO\]' "$PHP_LOG" 2>/dev/null; then
    falla "El log de PHP no tiene errores" "$(grep -E 'PHP |\[TEATRO\]' "$PHP_LOG" | head -3)"
else
    ok "El log de PHP no tiene errores"
fi

"$(dirname "$0")/reiniciar-bd.sh" >/dev/null

echo
if [[ $FALLOS -eq 0 ]]; then
    printf '\033[32m✓ %d pruebas correctas.\033[0m (La base quedó restaurada.)\n' "$TOTAL"
else
    printf '\033[31m✗ %d de %d pruebas fallaron.\033[0m (La base quedó restaurada.)\n' "$FALLOS" "$TOTAL"
    exit 1
fi
