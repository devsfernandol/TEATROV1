# Despliegue en el VPS

Esta carpeta no forma parte de la entrega: `.gitattributes` la excluye del ZIP.

## Arquitectura

```
Visitante ──HTTPS──▶ Cloudflare ──túnel──▶ cloudflared (servicio teatro-tunnel)
                                              │
                                              ▼ 127.0.0.1:8090 (solo accesible desde el servidor)
                                     teatro-web  (Nginx: límites por IP, rutas internas bloqueadas)
                                              │ red "frontal"
                                     teatro-php  (PHP 8.5.12-FPM, solo lectura)
                                              │ red "datos" (interna, sin salida a internet)
                                     teatro-db   (MySQL 8.4, sin puertos publicados)
```

- Todo vive en `/opt/teatro` y en contenedores propios. No toca los demás sitios del servidor.
- Las contraseñas se generan en el primer despliegue y quedan solo en `/opt/teatro/.env` (permisos 600).
- La aplicación se conecta con el usuario `teatro_app`, que solo tiene `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `TEATRO`.
- Cada día a las 04:00 (hora de Costa Rica) se restauran los datos de demostración.

## Desplegar o actualizar

Desde la máquina de desarrollo:

```bash
deploy/desplegar.sh root@IP_DEL_VPS            # última etiqueta (versión estable)
deploy/desplegar.sh root@IP_DEL_VPS v1.3.0     # una versión concreta
```

Es idempotente: actualiza el código y conserva los datos y las contraseñas.

## Operación en el servidor

```bash
cd /opt/teatro
docker compose --project-directory /opt/teatro -f deploy/docker-compose.yml ps     # estado
docker logs teatro-php                                                             # errores de PHP
journalctl -u teatro-tunnel -o cat | grep trycloudflare                           # dirección pública
/opt/teatro/deploy/reiniciar-demo.sh                                               # restaurar datos ya
```

## Dirección pública

El túnel es de tipo *quick tunnel* (`*.trycloudflare.com`), igual que los demás
sitios del servidor: no necesita cuenta, pero **la dirección cambia si se
reinicia el servicio `teatro-tunnel` o el servidor**. Para una dirección fija
hay que usar un túnel con nombre, con una cuenta de Cloudflare y un dominio.
