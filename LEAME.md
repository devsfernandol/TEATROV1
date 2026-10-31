# Teatro · Venta de entradas en línea

Solución a la prueba técnica PHP + MySQL. Los usuarios ven las obras de teatro
disponibles, eligen una, ingresan su identificador y reciben su número de
entrada. Si cierran el navegador, pueden volver a ver su entrada con ese número
y su identificador.

La guía **`GUIA-INSTALACION.pdf`** explica lo mismo paso a paso, con el guion
de pruebas completo.

## 1. Instalación (Linux con Docker)

```bash
sudo apt install -y unzip          # si el servidor no lo tiene
unzip teatro-v1.3.zip
cd teatro
sudo ./instalar.sh
```

El instalador muestra un menú:

```
  1) Instalar con un MySQL nuevo, en Docker (recomendado: no necesita nada más)
  2) Instalar usando un MySQL que ya existe (pide sus credenciales)
  3) Ver el estado
  4) Desinstalar
  0) Salir
```

| Opción | Qué hace | Qué pregunta |
|---|---|---|
| **1. MySQL nuevo** | Levanta Nginx, PHP 8.5 y MySQL 8.4 en contenedores, crea la base `TEATRO`, importa `database/teatro.sql` y crea el usuario `teatro_app` con una clave aleatoria. | Puerto (8080) y zona horaria (-06:00). Basta con pulsar Enter. |
| **2. MySQL existente** | Se conecta a su MySQL, importa la base `TEATRO` (o conserva la que ya tenga) y crea el usuario `teatro_app` con permisos mínimos. Solo levanta Nginx y PHP. | Dónde está MySQL (en este servidor o en otro), un usuario que pueda crear bases y usuarios (por ejemplo `root`) y su contraseña. Esa contraseña no se guarda. |

Al terminar muestra la dirección, por ejemplo **`http://IP_DEL_SERVIDOR:8080/`**,
que debe abrir la página **Obras disponibles** con 5 obras.

- Si Docker no está instalado, el instalador ofrece instalarlo con el script
  oficial de Docker.
- Volver a ejecutar `./instalar.sh` actualiza la instalación y conserva los
  datos, salvo que se elija empezar de cero.
- La configuración queda en `.env`, con permisos 600. La base de datos no
  publica ningún puerto.

### Requisitos

- Linux con **Docker Engine 24 o superior** y **Docker Compose v2**. Se probó
  en Ubuntu 24.04 con Docker 29.
- 1 GB de RAM libre y acceso a internet para descargar las imágenes.
- Para la opción 2: **MySQL 8.0.16 o superior**, o **MariaDB 10.3 o superior**,
  que aplican las restricciones `CHECK` de la base.

### HTTPS (opcional)

1. En la opción 1 o 2, responder `127.0.0.1:8080` como puerto, para que solo se
   acceda desde el propio servidor.
2. Poner delante un proxy con certificado. Por ejemplo, Caddy con este
   `/etc/caddy/Caddyfile`:

   ```
   teatro.ejemplo.com {
       reverse_proxy 127.0.0.1:8080
   }
   ```

La aplicación reconoce el HTTPS por `X-Forwarded-Proto` y marca la cookie como
`Secure`. Los límites por IP usan la IP real del visitante, que llega en
`X-Forwarded-For`.

## 2. Comandos útiles

Se ejecutan desde la carpeta `teatro`, con `sudo` si su usuario no está en el
grupo `docker`.

| Para | Comando |
|---|---|
| Ver el estado | `./instalar.sh` → 3, o `docker compose ps` |
| Ver los errores de PHP | `docker compose logs php` |
| Reiniciar | `docker compose restart` |
| Volver a los datos de ejemplo | `./instalar.sh` → 1 → 2 (opción 1) |
| Respaldar la base (opción 1) | `docker compose exec -T db sh -c 'mysqldump --single-transaction --no-tablespaces -uteatro_app -p"$TEATRO_DB_PASSWORD" TEATRO' > respaldo.sql` |
| Desinstalar | `./instalar.sh` → 4 |

## 3. Datos de prueba

| Cód. | Obra | Situación | ¿Aparece en la lista? |
|---|---|---|---|
| 1 | La casa de Bernarda Alba | 120 de 120 disponibles | Sí |
| 2 | Bodas de sangre | 78 de 80 disponibles | Sí |
| 3 | La vida es sueño | 2 de 5 disponibles | Sí, hasta que se vendan las 2 |
| 4 | Don Juan Tenorio | 200 de 200 disponibles | Sí |
| 5 | El sí de las niñas | 60 de 60 disponibles | Sí |
| 6 | Luces de bohemia | Agotada (0 de 3) | **No**: no tiene entradas |
| 7 | Fuenteovejuna | Su fecha ya pasó | **No**: su fecha no es mayor que la actual |

Las fechas se calculan al importar la base, así que siempre hay obras futuras.
`VENTAS` trae 10 ventas previas: la primera compra genera la entrada **11**.

## 4. Cómo probar

1. Abrir la dirección. Aparecen 5 obras: *Luces de bohemia* (agotada) y
   *Fuenteovejuna* (fecha pasada) no están.
2. Pulsar **Comprar entrada** en *La vida es sueño*, escribir `V-12345678` y
   confirmar. Aparece **¡Compra realizada con éxito!** con la entrada **11**.
3. Comprobar en la base que existe la venta 11 y que la obra 3 bajó de 2 a 1
   disponibles. Con la opción 1:

   ```bash
   docker compose exec db sh -c 'mysql -uteatro_app -p"$TEATRO_DB_PASSWORD" TEATRO'
   ```
   ```sql
   SELECT * FROM VENTAS ORDER BY numero_venta DESC LIMIT 1;
   SELECT disponibles FROM OBRA WHERE cod_obra = 3;
   ```

4. Comprar la última entrada de *La vida es sueño* (entrada 12): la obra deja
   de aparecer en la lista.
5. En otro navegador, pulsar **Consultar mi entrada** y escribir `11` y
   `V-12345678`. Se muestra la entrada.

| Caso de error | Resultado esperado |
|---|---|
| Identificador vacío o inválido (`ab`, `<script>`, `1' OR '1'='1`) | Mensaje claro; no se registra la venta. |
| F5 en la confirmación o varios clics seguidos en «Comprar» | Una sola venta. |
| 5.ª entrada de la misma obra con el mismo identificador | «Este identificador ya tiene el máximo de 4 entradas…» |
| Más de 20 compras en una hora desde el mismo equipo | «Demasiadas compras». |
| `comprar.php?obra=6`, `?obra=7`, `?obra=999` o `?obra=abc` | «Obra no disponible». |
| Cambiar el número en `confirmacion.php?venta=1` | «Entrada no encontrada». |
| Abrir `/database/teatro.sql`, `/.env` o `/includes/config.php` | 404. |
| Detener MySQL (`docker compose stop db`) y recargar | «Servicio no disponible», sin detalles técnicos. |

## 5. Configuración

Las opciones están en `.env`. Después de cambiarlas, ejecute
`docker compose up -d`.

| Variable | Defecto | Qué hace |
|---|---|---|
| `TEATRO_PUERTO` | 8080 | Puerto web. Con `127.0.0.1:8080` solo se accede desde el servidor. |
| `TEATRO_ZONA_HORARIA` | -06:00 | Zona horaria del MySQL en Docker, que decide qué obras ya pasaron. |
| `TEATRO_LIMITE_ENTRADAS_COMPRADOR` | 4 | Entradas por persona (identificador) para cada obra. |
| `TEATRO_LIMITE_COMPRAS_IP` | 20 | Compras por IP en una hora. |
| `TEATRO_LIMITE_CONSULTAS_IP` | 10 | Consultas de entradas por IP en 15 minutos. |

El valor `0` desactiva un límite. Las claves y la conexión a MySQL las escribe
el instalador; para cambiarlas, vuelva a ejecutarlo.

## 6. Solución de problemas

| Síntoma | Solución |
|---|---|
| «Su usuario no tiene permiso para usar Docker» | Ejecute `sudo ./instalar.sh`. |
| «Permiso denegado» al ejecutar `./instalar.sh` | Use `sudo bash instalar.sh`. Pasa si el ZIP se descomprimió con una herramienta que no conserva los permisos. |
| «El puerto 8080 ya está en uso» | El instalador pide otro puerto. |
| Opción 2: «Access denied» | Usuario o contraseña incorrectos, o el usuario no puede conectarse desde Docker. En un MySQL de este mismo servidor, elija «Instalado en este mismo servidor»: se conecta por el socket, sin red. |
| Opción 2: «Can't connect» con un MySQL en otro servidor | Ese MySQL debe aceptar conexiones de esta máquina (`bind-address` y cortafuegos). |
| «Servicio no disponible» | La aplicación no llega a MySQL. Vea el detalle en `docker compose logs php`. |
| «No hay obras disponibles» | Las fechas de los datos de ejemplo ya pasaron. Vuelva a cargarlos: `./instalar.sh` → 1 → 2. |

## 7. Decisiones de diseño

- **Sin sobreventa.** Cada compra es una transacción: el `UPDATE` descuenta la
  entrada solo si `disponibles > 0` y la obra no empezó, y bloquea la fila hasta
  el `COMMIT`. Las compras simultáneas se atienden de a una. Se probó con 20
  compras a la vez por las 2 últimas entradas: se registran exactamente 2.
- **Sin compras duplicadas.** Cada formulario lleva un token de un solo uso y,
  tras la compra, se redirige a la confirmación (POST/Redirect/GET).
- **Contra bots.** Máximo de entradas por persona y por obra, de compras por IP
  y de solicitudes por segundo en Nginx.
- **Seguridad.**
  - Sentencias preparadas.
  - Escape de toda la salida y una CSP que prohíbe los scripts.
  - Cookie `HttpOnly`, `SameSite` y `Secure` con HTTPS.
  - Nginx solo publica las 4 páginas y los estilos.
  - Contenedores de solo lectura.
  - MySQL en una red interna, con un usuario que solo tiene `SELECT`, `INSERT`,
    `UPDATE` y `DELETE` sobre `TEATRO`.
  - Sin claves por defecto: sin `.env`, Docker se niega a arrancar.
- **Errores.** El usuario nunca ve un error técnico; el detalle queda en el
  log, sin contraseñas.
- **Tipos de datos.**
  - `fecha_obra` es `DATETIME`: una función tiene fecha y hora.
  - `aforo` y `disponibles` son `SMALLINT UNSIGNED`.
  - Restricciones `CHECK`: `disponibles <= aforo` y `aforo > 0`.
  - Clave foránea de `VENTAS` a `OBRA`.

## 8. Archivos

```
index.php            Obras disponibles (primera página)
comprar.php          Pide el identificador y registra la venta
confirmacion.php     Muestra el número de entrada
consultar.php        Recupera una entrada con su número y el identificador
includes/            Conexión, consultas, sesión, límites y plantillas
assets/css/          Estilos (la aplicación no usa JavaScript)
database/teatro.sql  Respaldo de la base TEATRO con datos de prueba
instalar.sh          Instalador con menú
docker-compose.yml   Nginx + PHP; docker/mysql-*.yml agrega el modo de MySQL
docker/              Configuración de Nginx, PHP y MySQL para producción
.env.example         Referencia de la configuración que escribe el instalador
GUIA-INSTALACION.pdf Guía paso a paso
```
