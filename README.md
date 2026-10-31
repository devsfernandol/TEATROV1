# Teatro · Venta de entradas en línea

Solución a la prueba técnica de PHP + MySQL. Es un sistema web en el que el
usuario ve las obras de teatro disponibles, elige una, escribe su identificador
y recibe su número de entrada.

Hecho en **PHP sin frameworks**, **MySQL** y **HTML/CSS**, sin JavaScript.

---

## Índice

1. [Qué pide la prueba y cómo se resolvió](#1-qué-pide-la-prueba-y-cómo-se-resolvió)
2. [Requisitos](#2-requisitos)
3. [Instalación con XAMPP (Windows)](#3-instalación-con-xampp-windows)
4. [Instalación en Linux](#4-instalación-en-linux)
5. [Datos de prueba](#5-datos-de-prueba)
6. [Cómo usar el sistema](#6-cómo-usar-el-sistema)
7. [Pruebas manuales](#7-pruebas-manuales)
8. [Pruebas automáticas](#8-pruebas-automáticas)
9. [Cómo funciona por dentro](#9-cómo-funciona-por-dentro)
10. [Solución de problemas](#10-solución-de-problemas)
11. [Estructura del proyecto](#11-estructura-del-proyecto)

---

## 1. Qué pide la prueba y cómo se resolvió

| Lo que pide el enunciado | Dónde está |
|---|---|
| Base de datos `TEATRO` | `database/teatro.sql` |
| Tabla `OBRA` (cod_obra, nombre, fecha_obra, aforo, disponibles, sala) | `database/teatro.sql` |
| Tabla `VENTAS` (numero_venta, cod_obra, comprador, fecha_compra) | `database/teatro.sql` |
| Página inicial `index` con las obras que tienen entradas (`disponibles > 0`) y fecha mayor que la actual | `index.php` |
| Al elegir una obra, pedir el identificador del comprador | `comprar.php` |
| Registrar la venta con número autoincremental y mostrarlo | `comprar.php` → `confirmacion.php` |
| Restar 1 a `disponibles` de la obra | `includes/obras.php`, función `registrar_venta()` |
| Respaldo de la base de datos | `database/teatro.sql` |
| Archivo LEAME con los pasos adicionales | `LEAME.md` |
| Pensada para producción | `docker compose up -d` levanta Nginx + PHP-FPM + MySQL listos para producción ([LEAME, sección 3](LEAME.md#3-instalación-en-producción)) |
| Sin errores | Validaciones, manejo de errores y [105 pruebas automáticas](#8-pruebas-automáticas) |

El recorrido del usuario es:

```
index.php  ──"Comprar entrada"──▶  comprar.php  ──identificador──▶  confirmacion.php
(lista de obras)                   (pide el identificador)          (muestra el número de entrada)
```

---

## 2. Requisitos

| Componente | Versión |
|---|---|
| PHP | **8.5.12** (recomendado: es la versión con la que se desarrolló y probó). También sirve **8.4.27, 8.3.36 u 8.2.35** o posteriores, que tienen el parche de seguridad de *PHP2Shell* (CVE-2026-109618 y CVE-2026-109619). |
| Extensión de PHP | `pdo_mysql`, que viene activada en XAMPP, WAMP y Laragon |
| Base de datos | MySQL 5.7 o superior, o MariaDB 10.3 o superior |
| Servidor web | Apache (el de XAMPP sirve) o cualquier servidor con PHP |

---

## 3. Instalación con XAMPP (Windows)

### Paso 1: iniciar Apache y MySQL

Abrir el **XAMPP Control Panel** y pulsar **Start** en **Apache** y en **MySQL**.
Los dos deben quedar en verde.

### Paso 2: copiar el proyecto

Copiar la carpeta del proyecto en `C:\xampp\htdocs\` con el nombre `teatro`:

```
C:\xampp\htdocs\teatro\index.php
C:\xampp\htdocs\teatro\comprar.php
...
```

Si se descarga desde GitHub: botón **Code → Download ZIP**, descomprimir y
renombrar la carpeta `TEATROV1-main` a `teatro`.

### Paso 3: importar la base de datos

**Con phpMyAdmin:**

1. Abrir `http://localhost/phpmyadmin`.
2. Ir a la pestaña **Importar**.
3. Elegir el archivo `C:\xampp\htdocs\teatro\database\teatro.sql`.
4. Pulsar **Importar** (o **Continuar**).

No hace falta crear la base antes: el script crea `TEATRO`, sus dos tablas y
los datos de prueba.

**O desde la consola** (Símbolo del sistema, no PowerShell):

```bat
C:\xampp\mysql\bin\mysql.exe -u root < C:\xampp\htdocs\teatro\database\teatro.sql
```

### Paso 4: configurar la conexión (solo si hace falta)

La aplicación se conecta por defecto a `localhost:3306` con usuario `root` y
contraseña vacía, que es lo que trae XAMPP. **Si no cambió esa contraseña,
salte este paso.**

Si su MySQL tiene otra contraseña u otro usuario:

1. Copiar `includes\config.local.example.php` como `includes\config.local.php`.
2. Abrirlo y escribir el usuario y la contraseña:

   ```php
   return [
       'db' => [
           'host'     => 'localhost',
           'port'     => 3306,
           'user'     => 'root',
           'password' => 'su_contraseña',
       ],
   ];
   ```

### Paso 5: abrir la aplicación

Ir a **http://localhost/teatro/**. Debe aparecer **Obras disponibles** con 5 obras.

---

## 4. Instalación en Linux

### En producción con Docker (lo más simple)

```bash
cd teatro
cp .env.example .env        # opcional: cambiar la clave de la base y el puerto
docker compose up -d        # http://IP_DEL_SERVIDOR:8080
```

Crea la base, la importa y deja todo configurado para producción. Los detalles
(HTTPS, comandos útiles, opción con Apache) están en la
[sección 3 del LEAME](LEAME.md#3-instalación-en-producción).

### Con Apache

```bash
# 1. Paquetes (Ubuntu / Debian)
sudo apt install apache2 php php-mysql mysql-server

# 2. Copiar el proyecto
sudo git clone https://github.com/devsfernandol/TEATROV1.git /var/www/html/teatro

# 3. Importar la base de datos
sudo mysql < /var/www/html/teatro/database/teatro.sql

# 4. Crear un usuario para la aplicación (en Ubuntu root no entra con contraseña)
sudo mysql -e "CREATE USER 'teatro'@'localhost' IDENTIFIED BY 'una_clave_segura';
               GRANT SELECT, INSERT, UPDATE, DELETE ON TEATRO.* TO 'teatro'@'localhost';"

# 5. Configurar la conexión con ese usuario
cd /var/www/html/teatro
sudo cp includes/config.local.example.php includes/config.local.php
sudo nano includes/config.local.php      # user = teatro, password = una_clave_segura
```

Abrir **http://localhost/teatro/**.

> En lugar del paso 5 también se pueden usar variables de entorno:
> `TEATRO_DB_HOST`, `TEATRO_DB_PORT`, `TEATRO_DB_NAME`, `TEATRO_DB_USER` y
> `TEATRO_DB_PASSWORD`.

---

## 5. Datos de prueba

`database/teatro.sql` carga 7 obras. Sus fechas se calculan **a partir del
día en que se importa**, así que siempre hay obras futuras para probar.

| Cód. | Obra | Fecha | Aforo | Disponibles | ¿Aparece en la lista? |
|---|---|---|---|---|---|
| 1 | La casa de Bernarda Alba | en 3 días, 20:00 | 120 | 120 | Sí |
| 2 | Bodas de sangre | en 7 días, 19:30 | 80 | 78 | Sí |
| 3 | La vida es sueño | en 10 días, 18:00 | 5 | **2** | Sí, hasta que se vendan las 2 |
| 4 | Don Juan Tenorio | en 14 días, 21:00 | 200 | 200 | Sí |
| 5 | El sí de las niñas | en 21 días, 17:00 | 60 | 60 | Sí |
| 6 | Luces de bohemia | en 5 días, 20:30 | 3 | **0** | **No**: está agotada |
| 7 | Fuenteovejuna | **hace 2 días** | 50 | 48 | **No**: su fecha ya pasó |

La tabla `VENTAS` trae 10 ventas previas, así que la primera compra nueva
genera la entrada **número 11**.

### Volver al estado inicial

Importar `database/teatro.sql` otra vez. Borra y vuelve a crear las tablas con
los datos de prueba.

### Agregar obras

El enunciado no pide una pantalla para administrar obras, así que se agregan
con SQL (phpMyAdmin → pestaña **SQL**):

```sql
INSERT INTO TEATRO.OBRA (nombre, fecha_obra, aforo, disponibles, sala)
VALUES ('Yerma', '2026-12-15 20:00:00', 100, 100, 'Sala Principal');
```

- `cod_obra` no se escribe: es autoincremental.
- La fecha debe ser futura para que la obra aparezca en la lista.
- `disponibles` no puede ser mayor que `aforo`. La base lo rechaza.

---

## 6. Cómo usar el sistema

1. **Página principal** (`http://localhost/teatro/`). Lista las obras con
   entradas disponibles y fecha futura, ordenadas por fecha. Cada una muestra
   el nombre, la fecha y hora, la sala y las entradas que quedan.
2. **Comprar.** Al pulsar **Comprar entrada** se muestra la obra elegida y se
   pide el **identificador** del comprador (por ejemplo, su documento de
   identidad).
3. **Confirmación.** Al enviar el formulario se registra la venta y se muestra
   el **número de entrada**, junto con la obra, la fecha, la sala y el
   comprador.

### Formato del identificador

El enunciado no define el formato, así que se acepta un documento de identidad
de **5 a 20 caracteres** con letras, números y guiones, que empiece y termine
con letra o número.

Antes de validarlo se quitan los espacios y los puntos y se pasa a mayúsculas.
Por ejemplo, `v-12.345.678` se guarda como `V-12345678`.

| Ejemplo | ¿Válido? |
|---|---|
| `V-12345678` | Sí |
| `12345678` | Sí |
| `AB123` | Sí (mínimo 5 caracteres) |
| `ab` | No: muy corto |
| `-1234` | No: empieza con guion |
| `<script>` | No: caracteres no permitidos |

---

## 7. Pruebas manuales

Hacer esto en el navegador después de importar la base.

### Recorrido principal

1. **Abrir `http://localhost/teatro/`.**
   Aparecen 5 obras. *Luces de bohemia* (agotada) y *Fuenteovejuna* (fecha
   pasada) **no** aparecen.
2. **Pulsar "Comprar entrada" en *La vida es sueño*.**
   Aparece la obra elegida y el campo del identificador.
3. **Escribir `V-12345678` y pulsar "Comprar entrada".**
   Aparece "¡Compra realizada con éxito!" con la **entrada número 11**.
4. **Comprobar en la base de datos** (phpMyAdmin → SQL):

   ```sql
   SELECT * FROM TEATRO.VENTAS ORDER BY numero_venta DESC LIMIT 1;
   -- numero_venta 11, cod_obra 3, comprador V-12345678, fecha_compra = ahora

   SELECT nombre, aforo, disponibles FROM TEATRO.OBRA WHERE cod_obra = 3;
   -- disponibles bajó de 2 a 1
   ```

5. **Volver a la lista y comprar otra entrada de *La vida es sueño*.**
   Se genera la entrada 12 y la obra **desaparece de la lista**, porque se
   quedó sin entradas.

### Casos de error

| Qué hacer | Qué debe pasar |
|---|---|
| Enviar el formulario con el identificador vacío | "Ingrese su identificador para continuar". No se registra venta. |
| Escribir `ab`, `<script>` o `1' OR '1'='1` | Mensaje con el formato esperado. No se registra venta. |
| Pulsar **F5** en la página de confirmación | Se muestra la misma entrada. No se crea otra venta. |
| Pulsar "Comprar entrada" varias veces seguidas | Se registra **una sola** venta. |
| Abrir `comprar.php?obra=6` (agotada) | "Obra no disponible" |
| Abrir `comprar.php?obra=7` (fecha pasada) | "Obra no disponible" |
| Abrir `comprar.php?obra=999` o `comprar.php?obra=abc` | "Obra no disponible" |
| Abrir `confirmacion.php?venta=1` (una venta de otra persona) | "Entrada no encontrada": no se ven entradas ajenas. |
| Detener MySQL en XAMPP y recargar | "Servicio no disponible", sin detalles técnicos. |
| Abrir dos pestañas y comprar la última entrada en las dos | Solo una compra se registra; la otra recibe "Entradas no disponibles". |

---

## 8. Pruebas automáticas

La carpeta `dev/` tiene un entorno de desarrollo y pruebas automáticas para
**Linux o WSL**. Usa su propio PHP 8.5.12 y su propio MySQL dentro de `.dev/`,
sin `sudo` y sin tocar el MySQL ni el Apache del sistema.

> `dev/` no es necesario para usar el sistema y no va en el paquete de entrega.

### 8.1 Preparar el entorno (una sola vez)

```bash
sudo apt install build-essential libssl-dev zlib1g-dev mysql-server curl python3
```

### 8.2 Levantar la aplicación

```bash
dev/iniciar.sh
```

La primera vez tarda unos minutos: compila PHP 8.5.12 desde php.net
(verificando su SHA-256) y crea la base. Después arranca en segundos.

| | |
|---|---|
| Aplicación | http://localhost:8000 (8 procesos en paralelo para probar concurrencia real) |
| MySQL | `127.0.0.1:3307`, usuario `teatro_app` / `teatro_dev` |

`Ctrl+C` detiene la aplicación. `dev/detener.sh` detiene MySQL.

### 8.3 Pruebas funcionales: `dev/pruebas.sh`

En **otra terminal**, con la aplicación levantada:

```bash
dev/pruebas.sh
```

Ejecuta **105 pruebas** de punta a punta en unos 30 segundos. Al final
debe decir `✓ 105 pruebas correctas.`

| Grupo | Qué comprueba |
|---|---|
| Lista de obras | Solo aparecen las disponibles y futuras, ordenadas por fecha, con todos sus datos |
| Seguridad | Cabeceras HTTP, cookie de sesión, CSRF, XSS e inyección SQL |
| Validación | Parámetros e identificadores inválidos, valores extremos (20 000 caracteres, bytes no UTF-8, arreglos) y los límites válidos |
| Compra | La venta se guarda en `VENTAS`, `disponibles` baja en 1 y se muestra el número |
| Doble envío y privacidad | F5, doble clic y acceso a entradas de otros |
| Concurrencia | 20 compras simultáneas por 2 entradas, el mismo formulario 10 veces a la vez, dos pestañas y el mismo identificador desde 5 navegadores |
| Bloqueos de MySQL | La compra se reintenta sola si MySQL da *deadlock* o tiempo de espera |
| Integridad | `disponibles = aforo − ventas` en todas las obras |
| Log de PHP | Sin errores ni avisos |

La base se restaura antes y después, así que se puede ejecutar las veces que
haga falta.

### 8.4 Prueba de instalación: `dev/prueba-instalacion.sh`

```bash
dev/prueba-instalacion.sh
```

Simula lo que haría el evaluador, en alrededor de 1 minuto:

1. Genera el ZIP de entrega y revisa que tenga lo necesario y nada más.
2. Lo descomprime en una carpeta limpia, dentro de una subcarpeta `/teatro/`.
3. Importa `database/teatro.sql` dos veces y comprueba que el esquema coincida
   con el enunciado.
4. Ejecuta las 105 pruebas funcionales sobre esa copia.
5. Comprueba que, con MySQL caído o con la contraseña mal, el usuario ve una
   página amigable y el detalle queda solo en el log.

Usa el **último commit**, no los cambios sin confirmar.

### 8.5 Otros scripts

| Script | Qué hace |
|---|---|
| `dev/reiniciar-bd.sh` | Restaura la base desde `database/teatro.sql` |
| `dev/empaquetar.sh [versión]` | Genera `dist/teatro.zip` (la entrega) desde un commit o etiqueta |
| `dev/detener.sh` | Detiene el MySQL del proyecto (los datos se conservan) |
| `dev/instalar-php.sh` | Compila PHP en `.dev/php` (lo llama `iniciar.sh`) |

Para empezar desde cero:

```bash
dev/detener.sh && rm -rf .dev && dev/iniciar.sh
```

---

## 9. Cómo funciona por dentro

### Base de datos

| Campo | Tipo | Motivo |
|---|---|---|
| `OBRA.cod_obra` | `INT UNSIGNED AUTO_INCREMENT` | Clave primaria |
| `OBRA.nombre` | `VARCHAR(150)` | Títulos largos |
| `OBRA.fecha_obra` | `DATETIME` | La función tiene fecha **y hora** |
| `OBRA.aforo`, `OBRA.disponibles` | `SMALLINT UNSIGNED` | Hasta 65 535 butacas, sin negativos |
| `OBRA.sala` | `VARCHAR(50)` | Nombre de la sala |
| `VENTAS.numero_venta` | `INT UNSIGNED AUTO_INCREMENT` | Número de entrada |
| `VENTAS.cod_obra` | `INT UNSIGNED` + clave foránea | Toda venta pertenece a una obra existente |
| `VENTAS.comprador` | `VARCHAR(20)` | Identificador del comprador |
| `VENTAS.fecha_compra` | `DATETIME DEFAULT CURRENT_TIMESTAMP` | Momento de la compra |

Además tiene restricciones `CHECK` (`aforo > 0`, `disponibles <= aforo`), un
índice para la consulta de la página principal y `utf8mb4` para acentos y eñes.

### Cómo se registra una venta sin vender de más

Todo ocurre dentro de una **transacción**:

```sql
-- 1. Descontar la entrada solo si todavía hay y la obra no ha empezado
UPDATE OBRA SET disponibles = disponibles - 1
 WHERE cod_obra = ? AND disponibles > 0 AND fecha_obra > NOW();

-- 2. Solo si el UPDATE modificó la fila:
INSERT INTO VENTAS (cod_obra, comprador) VALUES (?, ?);

-- 3. COMMIT y se muestra LAST_INSERT_ID() como número de entrada
```

Si dos personas compran la última entrada al mismo tiempo, MySQL bloquea la
fila y atiende las dos actualizaciones de a una. La primera descuenta la
entrada; la segunda ya no encuentra `disponibles > 0`, no se registra nada y
recibe un mensaje claro.

Si con mucha carga MySQL aborta la transacción por un bloqueo (errores 1205 y
1213), la compra se reintenta hasta 3 veces. La transacción fallida se deshace
completa, así que reintentar no duplica nada.

### Seguridad y prevención de errores

| Riesgo | Cómo se previene |
|---|---|
| Inyección SQL | Todas las consultas usan sentencias preparadas de PDO |
| XSS | Todo lo que se muestra pasa por `htmlspecialchars` |
| Compra duplicada (doble clic, F5, Atrás) | Cada formulario lleva un token de un solo uso y después de comprar se redirige a la confirmación (POST/Redirect/GET) |
| CSRF | El mismo token: un formulario de otro sitio no puede comprar |
| Ver entradas de otros | La confirmación solo muestra las ventas hechas en esa misma sesión |
| Datos manipulados | La obra y el identificador se validan en el servidor y la disponibilidad se vuelve a comprobar al comprar |
| Errores técnicos en pantalla | Se registran en el log y el usuario ve una página amigable, también si MySQL no responde |
| Zona horaria | "Fecha mayor que la actual" la evalúa MySQL con `NOW()`, no PHP |
| Clickjacking, sniffing, caché | Cabeceras `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options` y `Cache-Control` |
| Acceso a archivos internos | `includes/` y `database/` tienen `.htaccess` que bloquea el acceso desde el navegador |

---

## 10. Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| "Servicio no disponible" | La aplicación no se conecta a MySQL. Verifique que MySQL esté iniciado, que se haya importado `database/teatro.sql` y que el usuario y la contraseña sean correctos ([paso 4](#paso-4-configurar-la-conexión-solo-si-hace-falta)). El detalle queda en `C:\xampp\php\logs\php_error_log` o `C:\xampp\apache\logs\error.log`. |
| Página en blanco o se descarga el código PHP | Apache no está ejecutando PHP. Inicie Apache y entre por `http://localhost/...`, no abriendo el archivo directamente. |
| "No hay obras disponibles" | No se importó la base, o se importó hace semanas y las fechas ya pasaron. Impórtela de nuevo. |
| "Su navegador no está aceptando cookies" | La compra usa una cookie de sesión. Habilite las cookies para `localhost`. |
| `ERROR 1045 Access denied` al importar | La contraseña de root no es vacía. Use `mysql -u root -p` y escríbala. |

Para ver el error técnico en pantalla mientras diagnostica, agregue
`'debug' => true,` en `includes/config.local.php`. **No lo deje activado.**

---

## 11. Estructura del proyecto

```
teatro/
├── index.php                 Página principal: obras disponibles
├── comprar.php               Pide el identificador y registra la venta
├── confirmacion.php          Muestra el número de entrada
├── includes/
│   ├── bootstrap.php         Arranque: errores, cabeceras de seguridad y sesión
│   ├── config.php            Conexión por defecto (XAMPP) y variables de entorno
│   ├── config.local.example.php  Plantilla para otras credenciales
│   ├── db.php                Conexión PDO
│   ├── obras.php             Consultas de obras y registro de ventas
│   ├── sesion.php            Sesión y tokens del formulario
│   ├── helpers.php           Escape, fechas en español y validación
│   └── layout.php            Cabecera, pie y páginas de mensaje
├── assets/css/estilos.css    Estilos
├── database/teatro.sql       Respaldo de la base TEATRO con datos de prueba
├── LEAME.md                  Instrucciones de instalación de la entrega
├── docker-compose.yml        Producción con Docker (Nginx + PHP-FPM + MySQL)
├── .env.example              Configuración opcional de Docker
├── docker/                   Configuración de Nginx, PHP y MySQL para Docker
├── deploy/                   Mi despliegue propio con túnel de Cloudflare (no es parte de la entrega)
└── dev/                      Entorno de desarrollo y pruebas automáticas (no es parte de la entrega)
```
