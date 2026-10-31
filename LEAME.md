# Teatro · Venta de entradas en línea

Solución a la prueba técnica PHP + MySQL. Los usuarios ven las obras de teatro
disponibles, eligen una, ingresan su identificador y reciben su número de
entrada. Si cierran el navegador, pueden volver a ver su entrada con ese número
y su identificador.

**Resumen para instalar:**

- **Para probarla en su equipo (XAMPP):** copiar la carpeta en `htdocs`,
  importar `database/teatro.sql` y abrir `http://localhost/teatro/`. Con XAMPP,
  cuyo usuario es `root` sin contraseña, no hace falta configurar nada más
  ([sección 2](#2-instalación-local-xampp)).
- **Para levantarla en producción (Docker):** dentro de la carpeta, ejecutar
  `docker compose up -d` y abrir `http://IP_DEL_SERVIDOR:8080/`. La base se
  crea y se importa sola ([sección 3](#3-instalación-en-producción)).

## 1. Requisitos

| Componente | Versión |
|---|---|
| PHP | **8.1 o superior**. Probado con PHP 8.1 y PHP 8.5. |
| Extensión de PHP | `pdo_mysql`, que viene activada en XAMPP, WAMP y Laragon |
| Base de datos | **MySQL 8.0.16 o superior**, o **MariaDB 10.3 o superior** (XAMPP trae MariaDB). Desarrollado y probado con MySQL 8.0. |
| Servidor web | Apache (por ejemplo, el de XAMPP) o Nginx con PHP-FPM |
| Producción con Docker (opcional) | Docker Engine 24 o superior con `docker compose`. Reemplaza todo lo anterior: PHP, MySQL y el servidor web van en contenedores. |

> **¿Por qué no MySQL 5.7?** La base usa restricciones `CHECK` (por ejemplo,
> `disponibles <= aforo`). MySQL 5.7 las acepta pero no las aplica (se aplican
> desde MySQL 8.0.16; MariaDB las aplica desde la 10.2). Además, MySQL 5.7 dejó
> de tener soporte en octubre de 2023.

## 2. Instalación local (XAMPP)

### Paso 1: copiar los archivos

Copiar la carpeta `teatro` completa dentro de `C:\xampp\htdocs\`, de modo que
quede `C:\xampp\htdocs\teatro\index.php`.

La aplicación funciona tanto en una subcarpeta (`/teatro/`) como en la raíz del sitio.

### Paso 2: restaurar la base de datos

El archivo `database/teatro.sql` crea el esquema **`TEATRO`** con sus tablas
**`OBRA`** y **`VENTAS`** y carga datos de prueba. Puede importarse de dos formas:

- **phpMyAdmin** (`http://localhost/phpmyadmin`): abrir la pestaña **Importar**,
  elegir `database/teatro.sql` y pulsar **Importar** (o **Continuar**). No hace
  falta crear la base antes, porque el script la crea.
- **Consola** (Símbolo del sistema, no PowerShell):

  ```bat
  C:\xampp\mysql\bin\mysql.exe -u root < C:\xampp\htdocs\teatro\database\teatro.sql
  ```

> Las fechas de las obras se calculan a partir del momento de la importación,
> así que siempre habrá obras futuras para probar. Para volver al estado inicial
> basta con importar el archivo otra vez.

### Paso 3: configurar la conexión (solo si hace falta)

Por defecto, la aplicación se conecta a `localhost:3306` con el usuario `root` y
la contraseña vacía, que es la configuración de fábrica de XAMPP.
**Si sus credenciales son esas, puede saltar este paso.**

Si son distintas:

1. Copiar `includes/config.local.example.php` como `includes/config.local.php`.
2. Escribir en ese archivo el servidor, el puerto, el usuario y la contraseña.

### Paso 4: abrir la aplicación

Abrir **`http://localhost/teatro/`** en el navegador. Debe aparecer la página
**Obras disponibles** con 5 obras. Si aparece "Servicio no disponible", vea la
sección [Solución de problemas](#6-solución-de-problemas).

### Paso 5: comprobar que los archivos internos están protegidos

Abrir `http://localhost/teatro/database/teatro.sql`. Debe responder
**403 Forbidden** (acceso prohibido). XAMPP aplica los `.htaccess` que traen
`includes/`, `database/` y `docker/`.

## 3. Instalación en producción

Hay tres formas. La **opción A (Docker)** es la más simple: un solo comando
levanta el servidor web, PHP y MySQL ya configurados para producción. Las
opciones B y C son para un servidor que ya tiene Apache o Nginx.

En las tres, **solo se pueden abrir desde el navegador las páginas públicas y la
hoja de estilos**. Las carpetas `includes/`, `database/` y `docker/` quedan
bloqueadas por la configuración del servidor, sin depender de los `.htaccess`.

### Opción A: Docker (recomendada)

Requiere un servidor (Linux, Windows o macOS) con **Docker** y `docker compose`.
No hace falta instalar PHP, MySQL ni Apache.

1. **Copiar la carpeta `teatro` al servidor**, por ejemplo en `/opt/teatro`.
2. **(Recomendado) Revisar la configuración.** Copiar `.env.example` como `.env`
   y cambiar al menos `TEATRO_DB_PASSWORD`. En el mismo archivo se puede
   cambiar el puerto (`TEATRO_PUERTO`, por defecto `8080`), la zona horaria
   (`TEATRO_ZONA_HORARIA`, por defecto `-06:00`) y los límites contra compras
   masivas. Hacerlo **antes** del paso 3.
3. **Levantar la aplicación** desde la carpeta:

   ```bash
   cd /opt/teatro
   docker compose up -d
   ```

   La primera vez tarda uno o dos minutos: descarga las imágenes, prepara PHP,
   crea la base `TEATRO` e importa `database/teatro.sql` automáticamente.
4. **Comprobar que está en marcha:** `docker compose ps` debe mostrar los
   servicios `web`, `php` y `db` en estado `running` (`db` como `healthy`).
5. **Abrir `http://IP_DEL_SERVIDOR:8080/`** (o `http://localhost:8080/` en el
   mismo equipo). Debe aparecer **Obras disponibles** con 5 obras.
6. **Comprobar la protección:** `http://IP_DEL_SERVIDOR:8080/database/teatro.sql`
   debe responder **404**.

Qué queda en marcha:

| Servicio | Qué hace |
|---|---|
| `web` (Nginx) | Único puerto publicado. Solo ejecuta `index.php`, `comprar.php`, `confirmacion.php` y `consultar.php` y sirve `assets/`; cualquier otra ruta (`includes/`, `database/`, `.env`...) responde 404. Limita las solicitudes por IP. |
| `php` (PHP 8.5-FPM) | Configuración de producción: los errores van al log, nunca a la pantalla. |
| `db` (MySQL 8.4) | Sin puertos publicados: solo PHP puede conectarse. La aplicación usa el usuario `teatro_app`, que solo tiene `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `TEATRO`. La clave de `root` es aleatoria. |

Los tres servicios se reinician solos si fallan o si se reinicia el servidor.

Comandos útiles (desde la carpeta del proyecto):

| Para | Comando |
|---|---|
| Ver las tablas (paso 4 de las pruebas) | `docker compose exec db sh -c 'mysql -uteatro_app -p"$TEATRO_DB_PASSWORD" TEATRO'` |
| Ver los errores de PHP | `docker compose logs php` |
| Detener (los datos se conservan) | `docker compose down` |
| Volver a los datos de prueba iniciales | `docker compose down -v && docker compose up -d` |

**HTTPS con Docker:** si el servidor ya tiene un proxy inverso con certificado
(Nginx, Apache o Caddy), basta con reenviar el dominio a `http://127.0.0.1:8080`
y poner `TEATRO_PUERTO=127.0.0.1:8080` en `.env`, para que el puerto 8080 no
quede abierto hacia fuera. Con Caddy, por ejemplo:

```
teatro.ejemplo.com {
    reverse_proxy 127.0.0.1:8080
}
```

La aplicación toma la IP real del visitante de `X-Forwarded-For` y detecta el
HTTPS por `X-Forwarded-Proto`, que el proxy envía. Así la cookie de sesión se
marca `Secure` y los límites por IP se aplican a cada visitante.

> Si existe `includes/config.local.php` (de una instalación con XAMPP), bórrelo:
> tiene prioridad sobre la configuración de Docker.

### Opción B: servidor Linux con Apache

Ejemplo para Ubuntu o Debian:

```bash
# 1. Paquetes (si faltan)
sudo apt install apache2 php php-mysql mysql-server

# 2. Copiar el proyecto e importar la base
sudo cp -r teatro /var/www/html/teatro
sudo mysql < /var/www/html/teatro/database/teatro.sql

# 3. Usuario de la aplicación con los permisos mínimos
sudo mysql -e "CREATE USER 'teatro_app'@'localhost' IDENTIFIED BY 'una_clave_segura';
               GRANT SELECT, INSERT, UPDATE, DELETE ON TEATRO.* TO 'teatro_app'@'localhost';"

# 4. Conexión con ese usuario (método del paso 3 de la sección 2)
sudo cp /var/www/html/teatro/includes/config.local.example.php /var/www/html/teatro/includes/config.local.php
sudo nano /var/www/html/teatro/includes/config.local.php   # user = teatro_app, password = una_clave_segura
```

5. **Bloquear las carpetas internas.** Ubuntu y Debian ignoran los `.htaccess`
   por defecto (`AllowOverride None`), así que el bloqueo se hace en la
   configuración de Apache. Crear `/etc/apache2/conf-available/teatro.conf` con:

   ```apache
   <DirectoryMatch "^/var/www/html/teatro/(includes|database|docker)(/|$)">
       Require all denied
   </DirectoryMatch>
   <FilesMatch "^(\.env.*|docker-compose\.yml|.*\.md)$">
       Require all denied
   </FilesMatch>
   ```

   y activarlo:

   ```bash
   sudo a2enconf teatro && sudo systemctl reload apache2
   curl -I http://localhost/teatro/database/teatro.sql   # debe responder 403
   ```

6. **HTTPS** (con un dominio que apunte al servidor):

   ```bash
   sudo apt install certbot python3-certbot-apache
   sudo certbot --apache
   ```

7. **Solo si Apache está detrás de un proxy o balanceador:** para que los
   límites por IP vean la IP real del visitante y no la del proxy, activar
   `mod_remoteip` indicando la IP del proxy:

   ```bash
   sudo a2enmod remoteip
   echo 'RemoteIPHeader X-Forwarded-For
   RemoteIPTrustedProxy 10.0.0.5' | sudo tee /etc/apache2/conf-available/remoteip.conf
   sudo a2enconf remoteip && sudo systemctl reload apache2
   ```

Abrir `http://IP_DEL_SERVIDOR/teatro/` (o `https://dominio/teatro/` si se configuró el paso 6).

### Opción C: servidor Linux con Nginx y PHP-FPM

Pasos 1 a 4 iguales a la opción B, cambiando `apache2` por `nginx php-fpm` y
copiando el proyecto en `/var/www/teatro`. Luego crear
`/etc/nginx/sites-available/teatro` con una lista de lo único que se puede abrir:

```nginx
server {
    listen 80;
    server_name teatro.ejemplo.com;
    root /var/www/teatro;

    # Solo se ejecutan las páginas públicas.
    location ~ ^/(index|comprar|confirmacion|consultar)\.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php-fpm.sock;   # ver el nombre exacto con: ls /run/php/
    }

    location ^~ /assets/ { try_files $uri =404; }
    location = / { rewrite ^ /index.php last; }

    # Todo lo demás (includes/, database/, docker/, .env...) no existe para el navegador.
    location / { return 404; }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/teatro /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -I http://localhost/database/teatro.sql   # debe responder 404
```

Para HTTPS: `sudo apt install certbot python3-certbot-nginx && sudo certbot --nginx`.

## 4. Datos de prueba

| Cód. | Obra | Situación | ¿Aparece en la lista? |
|---|---|---|---|
| 1 | La casa de Bernarda Alba | 120 de 120 disponibles | Sí |
| 2 | Bodas de sangre | 78 de 80 disponibles | Sí |
| 3 | La vida es sueño | 2 de 5 disponibles | Sí, hasta que se vendan las 2 |
| 4 | Don Juan Tenorio | 200 de 200 disponibles | Sí |
| 5 | El sí de las niñas | 60 de 60 disponibles | Sí |
| 6 | Luces de bohemia | Agotada (0 de 3) | **No**: no tiene entradas |
| 7 | Fuenteovejuna | Su fecha ya pasó | **No**: su fecha no es mayor que la actual |

La tabla `VENTAS` trae 10 ventas previas, así que la primera compra que se haga
genera la entrada número **11**.

## 5. Cómo probar la solución

En Docker, usar `http://localhost:8080/` en lugar de `http://localhost/teatro/`.

### Recorrido principal

1. **Abrir `http://localhost/teatro/`.**
   Aparecen 5 obras ordenadas por fecha. *Luces de bohemia* (agotada) y
   *Fuenteovejuna* (fecha pasada) no aparecen.
2. **Pulsar "Comprar entrada" en *La vida es sueño*.**
   Se muestra la obra elegida y se pide el identificador.
3. **Escribir un identificador, por ejemplo `V-12345678`, y pulsar "Comprar entrada".**
   Aparece "¡Compra realizada con éxito!" con el **número de entrada 11**.
4. **Verificar en la base de datos** (phpMyAdmin → pestaña SQL, o la consola):

   ```sql
   SELECT * FROM TEATRO.VENTAS ORDER BY numero_venta DESC LIMIT 1;
   -- Venta 11, cod_obra 3, comprador V-12345678 y la fecha de la compra

   SELECT cod_obra, nombre, aforo, disponibles FROM TEATRO.OBRA WHERE cod_obra = 3;
   -- disponibles bajó de 2 a 1
   ```

5. **Volver a la lista y comprar la última entrada de *La vida es sueño*.**
   Se genera la entrada 12 y la obra **deja de aparecer** en la lista, porque ya
   no tiene entradas.
6. **Recuperar una entrada desde otro navegador.** Abrir la aplicación en otro
   navegador (o en una ventana privada), pulsar **Consultar mi entrada** y
   escribir `11` y `V-12345678`. Se muestra la entrada 11.

### Casos de error controlados

| Acción | Resultado esperado |
|---|---|
| Pulsar "Comprar entrada" con el identificador vacío | Mensaje "Ingrese su identificador para continuar". No se registra ninguna venta. |
| Escribir un identificador inválido (`ab`, `<script>`, `1' OR '1'='1`) | Mensaje con el formato esperado. No se registra ninguna venta. |
| Pulsar F5 en la página de confirmación | Se vuelve a mostrar la misma entrada. No se genera otra venta. |
| Pulsar varias veces seguidas "Comprar entrada" | Se registra una sola venta. |
| Comprar una 5.ª entrada de la misma obra con el mismo identificador | Mensaje "Este identificador ya tiene el máximo de 4 entradas permitidas para esta obra". No se registra la venta. |
| Hacer más de 10 compras en una hora desde el mismo equipo | Página "Demasiadas compras". No se registra la venta. |
| Abrir `comprar.php?obra=6` (agotada), `?obra=7` (fecha pasada), `?obra=999` o `?obra=abc` | Mensaje "Obra no disponible". |
| Cambiar el número en `confirmacion.php?venta=1` | Mensaje "Entrada no encontrada": no se pueden ver entradas de otros compradores. |
| En "Consultar mi entrada", escribir un número con un identificador que no le corresponde | "No encontramos una entrada con ese número e identificador". |
| Hacer más de 10 consultas en 15 minutos desde el mismo equipo | Página "Demasiadas consultas". |
| Detener MySQL y recargar la página | Página "Servicio no disponible", sin ningún detalle técnico. |

> Para hacer muchas compras de prueba desde un mismo equipo, suba el límite de
> compras por IP: en XAMPP, con la sección `'limites'` de
> `includes/config.local.php` (ver el ejemplo); en Docker, con
> `TEATRO_LIMITE_COMPRAS_IP` en `.env`. El valor `0` desactiva un límite.

## 6. Solución de problemas

| Síntoma | Causa probable y solución |
|---|---|
| "Servicio no disponible" | La aplicación no puede conectarse a MySQL. Verifique que MySQL esté iniciado (en XAMPP, botón *Start* de MySQL), que se haya importado `database/teatro.sql` y que las credenciales sean correctas (paso 3). El detalle exacto del error queda en el log de errores de PHP o de Apache (en XAMPP: `C:\xampp\php\logs\php_error_log` o `C:\xampp\apache\logs\error.log`). |
| La página se ve en blanco o se descarga el código PHP | El servidor web no está ejecutando PHP. Verifique que Apache esté iniciado y que la URL empiece con `http://localhost/`: abrir el archivo directamente desde la carpeta no ejecuta PHP. |
| "No hay obras disponibles" | No se importaron los datos de prueba, o se importaron hace semanas y las fechas ya pasaron. Importe `database/teatro.sql` de nuevo. |
| "Su navegador no está aceptando cookies" | La compra necesita una cookie de sesión. Habilite las cookies para el sitio. |
| "Demasiadas compras" o "Demasiadas consultas" mientras se prueba | Es la protección contra compras masivas. Espere (1 hora o 15 minutos) o suba el límite como se indica al final de la sección 5. |
| `database/teatro.sql` se descarga desde el navegador | El servidor no está aplicando el bloqueo. En Apache con `AllowOverride None`, siga el paso 5 de la opción B; en Nginx, use la configuración de la opción C. |
| Docker: "Servicio no disponible" justo después de `docker compose up -d` | MySQL todavía está importando la base. Espere a que `docker compose ps` muestre `db` como `healthy` y recargue. |
| Docker: `port is already allocated` | El puerto 8080 está ocupado. Ponga otro en `.env` (`TEATRO_PUERTO=8081`) y ejecute `docker compose up -d` de nuevo. |
| Docker: se cambió `TEATRO_DB_PASSWORD` después del primer arranque y aparece "Servicio no disponible" | La clave se fija al crear la base. Recree la base con `docker compose down -v && docker compose up -d` (borra las ventas registradas). |

Para ver el detalle técnico de un error en pantalla mientras se diagnostica,
active la línea `'debug' => true,` en `includes/config.local.php` (ver
`includes/config.local.example.php`). **No la deje activada en producción.**

## 7. Decisiones de diseño

### Tipos de datos

| Campo | Tipo | Motivo |
|---|---|---|
| `OBRA.cod_obra` | `INT UNSIGNED AUTO_INCREMENT` | Clave primaria. No admite valores negativos. |
| `OBRA.nombre` | `VARCHAR(150) NOT NULL` | Longitud suficiente para títulos largos. |
| `OBRA.fecha_obra` | `DATETIME NOT NULL` | Una función tiene fecha **y hora**. Una obra de hoy a las 20:00 sigue a la venta durante el día y deja de estarlo cuando empieza. |
| `OBRA.aforo`, `OBRA.disponibles` | `SMALLINT UNSIGNED NOT NULL` | Hasta 65 535 butacas, ocupando 2 bytes. `UNSIGNED` impide valores negativos. |
| `OBRA.sala` | `VARCHAR(50) NOT NULL` | Nombre de la sala. |
| `VENTAS.numero_venta` | `INT UNSIGNED AUTO_INCREMENT` | Número de entrada autoincremental. |
| `VENTAS.cod_obra` | `INT UNSIGNED NOT NULL` + clave foránea | Toda venta corresponde a una obra existente. No se puede borrar una obra que tiene ventas. |
| `VENTAS.comprador` | `VARCHAR(20) NOT NULL` | Identificador del comprador. |
| `VENTAS.fecha_compra` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` | Momento exacto de la compra. |

Además, la base tiene restricciones `CHECK` (`aforo > 0`, `disponibles <= aforo`),
un índice `(fecha_obra, disponibles)` para la consulta de obras disponibles, un
índice `(cod_obra, comprador)` para contar las entradas de cada comprador, y usa
`utf8mb4` para que acentos y eñes se guarden y muestren correctamente.

### Cómo se evita la sobreventa

El descuento de la entrada es un `UPDATE` condicional dentro de una transacción:

```sql
UPDATE OBRA SET disponibles = disponibles - 1
 WHERE cod_obra = ? AND disponibles > 0 AND fecha_obra > NOW();
```

La venta solo se inserta si ese `UPDATE` modificó la fila. Si dos personas compran
la última entrada al mismo tiempo, MySQL atiende las dos actualizaciones de a una
y solo la primera encuentra entradas. La segunda recibe un mensaje claro y no se
registra nada.

Si con mucha carga MySQL aborta la transacción por un bloqueo (*deadlock* o
tiempo de espera agotado), la compra se reintenta automáticamente hasta 3 veces.
Como la transacción fallida se deshace por completo, reintentar no duplica nada.

### Protección contra compras masivas (bots)

| Capa | Qué impide | Dónde |
|---|---|---|
| Máximo de **4 entradas por identificador** para cada obra | Que una persona o un script acapare una obra con el mismo identificador. Se comprueba dentro de la misma transacción que descuenta la entrada, así que tampoco se puede superar comprando desde varios navegadores a la vez. | Base de datos (`includes/obras.php`) |
| Máximo de **10 compras por IP en una hora** | Que un script compre muchas entradas con identificadores distintos desde una misma conexión. | Aplicación (`includes/limites.php`), en cualquier servidor |
| Máximo de **10 consultas de entrada por IP en 15 minutos** | Que alguien adivine entradas ajenas probando números e identificadores. | Aplicación |
| Límite de solicitudes por segundo y por minuto | Ráfagas de peticiones automáticas. | Nginx (opción A, Docker) |

Los tres límites de la aplicación se configuran en `includes/config.local.php` o
con variables de entorno (ver `.env.example`).

> **Alcance:** estos límites frenan a un script desde una conexión o con un
> mismo identificador. Un ataque distribuido (miles de IP e identificadores
> inventados) solo se detiene verificando la identidad del comprador (por
> ejemplo, con cuentas de usuario, pago o un CAPTCHA), que queda fuera del
> alcance del enunciado.

### Recuperar una entrada

La confirmación solo se puede ver desde la sesión en que se compró, para que
nadie vea entradas ajenas cambiando el número en la URL. Si el comprador cierra
el navegador, entra en **Consultar mi entrada** y escribe su número de entrada y
su identificador: se exigen los dos datos y los intentos están limitados por IP.

### Compras simultáneas: escenarios probados

| Escenario | Resultado |
|---|---|
| 20 personas compran a la vez las 2 últimas entradas | Exactamente 2 ventas. Las otras 18 reciben "Entradas no disponibles" y nunca se venden más entradas que el aforo. |
| El mismo usuario envía el mismo formulario 10 veces a la vez (doble clic, conexión lenta) | 1 sola venta. Las 10 respuestas muestran la misma entrada. |
| El mismo usuario compra en dos pestañas a la vez | 2 ventas con números distintos: son dos compras intencionales. |
| El mismo identificador compra desde 5 navegadores a la vez | Exactamente 4 ventas (el máximo por persona); la quinta se rechaza. |
| MySQL está bloqueado momentáneamente | La compra se reintenta sola y se completa. |

### Identificador del comprador

El enunciado no define su formato. Se interpreta como un documento de identidad
de 5 a 20 caracteres con letras, números y guiones. Antes de validarlo se quitan
los espacios y los puntos y se pasa a mayúsculas, así que `v-12.345.678` se
guarda como `V-12345678`.

### Prevención de errores y seguridad

- **Ningún error técnico llega al usuario.** Se registra en el log del servidor y
  se muestra una página amigable, también cuando la base de datos no responde.
- **Inyección SQL:** todas las consultas usan sentencias preparadas (PDO).
- **XSS:** todo lo que se muestra se escapa con `htmlspecialchars`.
- **Compras duplicadas:** cada formulario lleva un token de un solo uso. Si se
  envía dos veces (doble clic, F5, botón Atrás), no se genera otra venta.
  Después de comprar se redirige a la confirmación (patrón POST/Redirect/GET).
- **Datos manipulados:** el código de obra y el identificador se validan en el
  servidor. La disponibilidad se vuelve a comprobar en el momento de la compra.
- **Archivos internos:** las carpetas `includes/`, `database/` y `docker/` se
  bloquean en el servidor web (sección 3) y, en Apache, también con `.htaccess`.
- **HTTPS:** la cookie de sesión se marca `Secure` cuando el visitante llega por
  HTTPS, también si hay un proxy o balanceador delante (`X-Forwarded-Proto`).
- **Zona horaria:** la regla "fecha mayor que la actual" la evalúa MySQL con
  `NOW()`, así que no depende de la configuración de PHP.

## 8. Estructura de archivos

```
├── index.php              Obras disponibles (página principal)
├── comprar.php            Pide el identificador y registra la venta
├── confirmacion.php       Muestra el número de entrada
├── consultar.php          Recupera una entrada con su número y el identificador
├── includes/
│   ├── bootstrap.php      Arranque: manejo de errores, cabeceras y sesión
│   ├── config.php         Configuración (valores por defecto de XAMPP y límites)
│   ├── config.local.example.php  Plantilla para credenciales y límites distintos
│   ├── db.php             Conexión PDO
│   ├── obras.php          Consultas de obras y registro de ventas
│   ├── sesion.php         Sesión y token del formulario de compra
│   ├── limites.php        Límites de compras y consultas por IP
│   ├── helpers.php        Utilidades (escape, fechas, validación)
│   └── layout.php         Cabecera, pie y páginas de mensaje
├── assets/css/            Hoja de estilos
├── database/teatro.sql    Respaldo de la base de datos TEATRO
├── docker-compose.yml     Producción con Docker: Nginx + PHP-FPM + MySQL (sección 3)
├── .env.example           Configuración opcional de Docker
└── docker/                Configuración de Nginx, PHP y del usuario de MySQL para Docker
```
