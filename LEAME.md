# Teatro · Venta de entradas en línea

Solución a la prueba técnica PHP + MySQL. Los usuarios ven las obras de teatro
disponibles, eligen una, ingresan su identificador y reciben su número de entrada.

**Resumen para instalar:** copiar la carpeta en el servidor web, importar
`database/teatro.sql` y abrir `http://localhost/teatro/`. Con XAMPP, cuyo usuario
es `root` sin contraseña, no hace falta configurar nada más.

## 1. Requisitos

| Componente | Versión |
|---|---|
| PHP | **8.5.12** (recomendado: es la versión con la que se desarrolló y probó). También sirve cualquier versión con soporte que tenga el parche de seguridad del 21 de octubre de 2026: **8.4.27, 8.3.36 u 8.2.35** o posteriores. Ese parche corrige las vulnerabilidades críticas *PHP2Shell* (CVE-2026-109618 y CVE-2026-109619). |
| Extensión de PHP | `pdo_mysql`, que viene activada en XAMPP, WAMP y Laragon |
| Base de datos | MySQL 5.7 o superior, o MariaDB 10.3 o superior |
| Servidor web | Apache (por ejemplo, el de XAMPP) o cualquier servidor con PHP |

## 2. Instalación

### Paso 1: copiar los archivos

Copiar la carpeta `teatro` completa dentro de la carpeta pública del servidor web:

- XAMPP (Windows): `C:\xampp\htdocs\teatro`
- Apache (Linux): `/var/www/html/teatro`

La aplicación funciona tanto en una subcarpeta (`/teatro/`) como en la raíz del sitio.

### Paso 2: restaurar la base de datos

El archivo `database/teatro.sql` crea el esquema **`TEATRO`** con sus tablas
**`OBRA`** y **`VENTAS`** y carga datos de prueba. Puede importarse de dos formas:

- **phpMyAdmin** (`http://localhost/phpmyadmin`): abrir la pestaña **Importar**,
  elegir `database/teatro.sql` y pulsar **Importar** (o **Continuar**). No hace
  falta crear la base antes, porque el script la crea.
- **Consola:**

  ```bash
  mysql -u root -p < database/teatro.sql
  ```

  En XAMPP para Windows, desde el **Símbolo del sistema (CMD)**, no PowerShell:

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
sección [Solución de problemas](#5-solución-de-problemas).

## 3. Datos de prueba

| Obra | Situación | ¿Aparece en la lista? |
|---|---|---|
| La casa de Bernarda Alba | 120 de 120 disponibles | Sí |
| Bodas de sangre | 78 de 80 disponibles | Sí |
| La vida es sueño | 2 de 5 disponibles | Sí, hasta que se vendan las 2 |
| Don Juan Tenorio | 200 de 200 disponibles | Sí |
| El sí de las niñas | 60 de 60 disponibles | Sí |
| Luces de bohemia | Agotada (0 de 3) | **No**: no tiene entradas |
| Fuenteovejuna | Su fecha ya pasó | **No**: su fecha no es mayor que la actual |

La tabla `VENTAS` trae 10 ventas previas, así que la primera compra que se haga
genera la entrada número **11**.

## 4. Cómo probar la solución

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

### Casos de error controlados

| Acción | Resultado esperado |
|---|---|
| Pulsar "Comprar entrada" con el identificador vacío | Mensaje "Ingrese su identificador para continuar". No se registra ninguna venta. |
| Escribir un identificador inválido (`ab`, `<script>`, `1' OR '1'='1`) | Mensaje con el formato esperado. No se registra ninguna venta. |
| Pulsar F5 en la página de confirmación | Se vuelve a mostrar la misma entrada. No se genera otra venta. |
| Pulsar varias veces seguidas "Comprar entrada" | Se registra una sola venta. |
| Abrir `comprar.php?obra=6` (agotada), `?obra=7` (fecha pasada), `?obra=999` o `?obra=abc` | Mensaje "Obra no disponible". |
| Cambiar el número en `confirmacion.php?venta=1` | Mensaje "Entrada no encontrada": no se pueden ver entradas de otros compradores. |
| Detener MySQL y recargar la página | Página "Servicio no disponible", sin ningún detalle técnico. |

## 5. Solución de problemas

| Síntoma | Causa probable y solución |
|---|---|
| "Servicio no disponible" | La aplicación no puede conectarse a MySQL. Verifique que MySQL esté iniciado (en XAMPP, botón *Start* de MySQL), que se haya importado `database/teatro.sql` y que las credenciales sean correctas (paso 3). El detalle exacto del error queda en el log de errores de PHP o de Apache (en XAMPP: `C:\xampp\php\logs\php_error_log` o `C:\xampp\apache\logs\error.log`). |
| La página se ve en blanco o se descarga el código PHP | El servidor web no está ejecutando PHP. Verifique que Apache esté iniciado y que la URL empiece con `http://localhost/`: abrir el archivo directamente desde la carpeta no ejecuta PHP. |
| "No hay obras disponibles" | No se importaron los datos de prueba, o se importaron hace semanas y las fechas ya pasaron. Importe `database/teatro.sql` de nuevo. |
| "Su navegador no está aceptando cookies" | La compra necesita una cookie de sesión. Habilite las cookies para `localhost`. |

Para ver el detalle técnico de un error en pantalla mientras se diagnostica,
active la línea `'debug' => true,` en `includes/config.local.php` (ver
`includes/config.local.example.php`). **No la deje activada en producción.**

## 6. Decisiones de diseño

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
un índice `(fecha_obra, disponibles)` para la consulta de obras disponibles, y
usa `utf8mb4` para que acentos y eñes se guarden y muestren correctamente.

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

### Compras simultáneas: escenarios probados

| Escenario | Resultado |
|---|---|
| 20 personas compran a la vez las 2 últimas entradas | Exactamente 2 ventas. Las otras 18 reciben "Entradas no disponibles" y nunca se venden más entradas que el aforo. |
| El mismo usuario envía el mismo formulario 10 veces a la vez (doble clic, conexión lenta) | 1 sola venta. Las 10 respuestas muestran la misma entrada. |
| El mismo usuario compra en dos pestañas a la vez | 2 ventas con números distintos: son dos compras intencionales. |
| El mismo identificador compra desde 5 navegadores a la vez | 5 ventas con números distintos y sin repetir. |
| MySQL está bloqueado momentáneamente | La compra se reintenta sola y se completa. |

### Identificador del comprador

El enunciado no define su formato. Se interpreta como un documento de identidad
de 5 a 20 caracteres con letras, números y guiones. Antes de validarlo se quitan
los espacios y los puntos y se pasa a mayúsculas, así que `v-12.345.678` se
guarda como `V-12345678`.

### Prevención de errores

- **Ningún error técnico llega al usuario.** Se registra en el log del servidor y
  se muestra una página amigable, también cuando la base de datos no responde.
- **Inyección SQL:** todas las consultas usan sentencias preparadas (PDO).
- **XSS:** todo lo que se muestra se escapa con `htmlspecialchars`.
- **Compras duplicadas:** cada formulario lleva un token de un solo uso. Si se
  envía dos veces (doble clic, F5, botón Atrás), no se genera otra venta.
  Después de comprar se redirige a la confirmación (patrón POST/Redirect/GET).
- **Datos manipulados:** el código de obra y el identificador se validan en el
  servidor. La disponibilidad se vuelve a comprobar en el momento de la compra.
- **Privacidad:** la confirmación solo muestra las entradas compradas en el
  mismo navegador. Cambiar el número en la URL no permite ver entradas ajenas.
- **Zona horaria:** la regla "fecha mayor que la actual" la evalúa MySQL con
  `NOW()`, así que no depende de la configuración de PHP.

## 7. Estructura de archivos

```
├── index.php              Obras disponibles (página principal)
├── comprar.php            Pide el identificador y registra la venta
├── confirmacion.php       Muestra el número de entrada
├── includes/
│   ├── bootstrap.php      Arranque: manejo de errores, cabeceras y sesión
│   ├── config.php         Datos de conexión a la base (valores por defecto de XAMPP)
│   ├── config.local.example.php  Plantilla para credenciales distintas (paso 3)
│   ├── db.php             Conexión PDO
│   ├── obras.php          Consultas de obras y registro de ventas
│   ├── sesion.php         Sesión y token del formulario de compra
│   ├── helpers.php        Utilidades (escape, fechas, validación)
│   └── layout.php         Cabecera, pie y páginas de mensaje
├── assets/css/           Hoja de estilos
└── database/teatro.sql    Respaldo de la base de datos TEATRO
```
