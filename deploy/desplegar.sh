#!/usr/bin/env bash
# Despliega una versión de Teatro en el VPS, aislada en sus propios contenedores
# (/opt/teatro) y publicada solo a través de un túnel de Cloudflare.
#
# Uso: deploy/desplegar.sh usuario@servidor [referencia]   (por defecto la última etiqueta)
#      Opciones extra de ssh en SSH_OPTS (por ejemplo, -o ControlPath=...).
#
# Es idempotente: se puede ejecutar de nuevo para actualizar la versión publicada.
# Conserva los datos y las contraseñas generadas en el primer despliegue.

set -euo pipefail

DESTINO="${1:?Uso: deploy/desplegar.sh usuario@servidor [referencia]}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
REF="${2:-$(git -C "$RAIZ" describe --tags --abbrev=0)}"
# shellcheck disable=SC2206
SSH=(ssh ${SSH_OPTS:-} "$DESTINO")

echo "→ Desplegando $REF ($(git -C "$RAIZ" rev-parse --short "$REF^{commit}")) en $DESTINO"

# 1. Código de la aplicación (mismo contenido que el paquete de entrega) y configuración de despliegue.
"${SSH[@]}" 'mkdir -p /opt/teatro && rm -rf /opt/teatro/app.nuevo /opt/teatro/deploy.nuevo'
git -C "$RAIZ" archive --format=tar --prefix=app.nuevo/ "$REF" | "${SSH[@]}" 'tar -x -C /opt/teatro'
tar -C "$RAIZ" -c --transform 's,^deploy,deploy.nuevo,' deploy | "${SSH[@]}" 'tar -x -C /opt/teatro'

"${SSH[@]}" 'bash -s' <<'REMOTO'
set -euo pipefail
cd /opt/teatro

# 2. Contraseñas: se generan una sola vez y quedan solo en el servidor.
if [[ ! -f .env ]]; then
    umask 077
    printf 'MYSQL_ROOT_PASSWORD=%s\nTEATRO_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > .env
fi
chmod 600 .env
TEATRO_DB_PASSWORD=$(grep '^TEATRO_DB_PASSWORD=' .env | cut -d= -f2)

# 3. Configuración local de la aplicación (método documentado en el LEAME, paso 3).
cat > app.nuevo/includes/config.local.php <<PHP
<?php
return ['db' => ['host' => 'db', 'port' => 3306, 'user' => 'teatro_app', 'password' => '$TEATRO_DB_PASSWORD']];
PHP
chown root:82 app.nuevo/includes/config.local.php   # 82 = www-data en la imagen de PHP (Alpine)
chmod 640 app.nuevo/includes/config.local.php
chmod 644 deploy.nuevo/db-init/02-usuario.sh        # se carga con source, no se ejecuta
chmod 755 deploy.nuevo/reiniciar-demo.sh

# 4. Reemplazo de los archivos.
rm -rf app.anterior deploy.anterior
[[ -d app ]] && mv app app.anterior
[[ -d deploy ]] && mv deploy deploy.anterior
mv app.nuevo app
mv deploy.nuevo deploy

# 5. Contenedores. Se reinician web y php para que monten la carpeta app nueva.
COMPOSE=(docker compose --project-directory /opt/teatro -f deploy/docker-compose.yml)
"${COMPOSE[@]}" up -d --build --remove-orphans
"${COMPOSE[@]}" restart php web > /dev/null

# 6. Túnel de Cloudflare (mismo esquema que los demás sitios del servidor).
cat > /etc/systemd/system/teatro-tunnel.service <<'UNIT'
[Unit]
Description=Cloudflare Tunnel para Teatro (127.0.0.1:8090)
After=network-online.target docker.service
Wants=network-online.target

[Service]
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8090
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now teatro-tunnel.service > /dev/null 2>&1

# 7. Restauración diaria de los datos de demostración (04:00 hora de Costa Rica = 10:00 UTC).
cat > /etc/cron.d/teatro-reinicio-demo <<'CRON'
0 10 * * * root /opt/teatro/deploy/reiniciar-demo.sh >> /var/log/teatro-reinicio-demo.log 2>&1
CRON
chmod 644 /etc/cron.d/teatro-reinicio-demo

rm -rf app.anterior deploy.anterior
"${COMPOSE[@]}" ps --format 'table {{.Name}}\t{{.Status}}'
REMOTO

echo "→ Dirección pública del túnel:"
for _ in $(seq 1 30); do
    URL=$("${SSH[@]}" "journalctl -u teatro-tunnel --no-pager -o cat | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1" || true)
    [[ -n "$URL" ]] && break
    sleep 2
done
echo "${URL:-(todavía no disponible: journalctl -u teatro-tunnel)}"
