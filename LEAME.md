# Teatro · Venta de entradas en línea

Aplicación en PHP + MySQL para comprar entradas de teatro. Muestra las obras
disponibles, pide el identificador del comprador, registra la venta y entrega
el número de entrada.

## Requisitos

- PHP 8.0 o superior con la extensión `pdo_mysql` (incluida en XAMPP, WAMP, Laragon, etc.).
- MySQL 5.7+ / 8.x o MariaDB 10.3+, con el motor InnoDB.
- Un servidor web con PHP (Apache, Nginx + PHP-FPM o el servidor integrado de PHP).

## Instalación

1. **Copiar los archivos** en una carpeta del servidor web, por ejemplo
   `htdocs/teatro` (XAMPP) o `/var/www/html/teatro` (Apache en Linux).

2. **Restaurar la base de datos** desde `database/teatro.sql`. El script crea el
   esquema `TEATRO`, sus tablas y datos de prueba:

   ```bash
   mysql -u root -p < database/teatro.sql
   ```

   También se puede importar desde phpMyAdmin (pestaña *Importar*).

   > Las fechas de los datos de prueba se calculan a partir de la fecha de
   > restauración, así que siempre habrá obras futuras para probar. Si vuelve a
   > importar el script, la base se reinicia a su estado inicial.

3. **Configurar la conexión.** Por defecto se usa `localhost:3306`, usuario
   `root` y contraseña vacía (la configuración de fábrica de XAMPP). Si sus
   credenciales son distintas, elija una de estas opciones:

   - Copiar `includes/config.local.example.php` como `includes/config.local.php`
     y escribir allí los datos de conexión (recomendado), o
   - Definir las variables de entorno `TEATRO_DB_HOST`, `TEATRO_DB_PORT`,
     `TEATRO_DB_NAME`, `TEATRO_DB_USER` y `TEATRO_DB_PASSWORD`.

4. **Abrir** `http://localhost/teatro/` (o la ruta correspondiente) en el navegador.

Para una prueba rápida sin Apache también puede usarse el servidor integrado de PHP:

```bash
php -S localhost:8000
# Abrir http://localhost:8000
```

## Cómo probar

| Caso | Resultado esperado |
|---|---|
| Abrir la cartelera | Aparecen 5 obras. *Luces de bohemia* (agotada) y *Fuenteovejuna* (ya realizada) no aparecen. |
| Comprar una entrada | Se muestra el número de entrada. Las disponibles de la obra bajan en uno y la venta queda en `VENTAS`. |
| Comprar las 2 últimas entradas de *La vida es sueño* | La obra deja de aparecer en la cartelera. |
| Identificador vacío o inválido (ej. `ab`, `<script>`) | Se muestra un mensaje de error y no se registra ninguna venta. |
| Refrescar (F5) la página de confirmación o hacer doble clic en "Confirmar compra" | No se genera una segunda venta. |
| Abrir `comprar.php?obra=6`, `?obra=7`, `?obra=999` o `?obra=abc` | Mensaje "Obra no disponible" (HTTP 404). |
| Cambiar el número en `confirmacion.php?venta=1` | No se muestran entradas compradas en otras sesiones. |

Consultas útiles para verificar en la base:

```sql
SELECT * FROM TEATRO.OBRA;
SELECT * FROM TEATRO.VENTAS ORDER BY numero_venta DESC;
```

## Decisiones de diseño

### Base de datos

| Campo | Tipo | Motivo |
|---|---|---|
| `OBRA.cod_obra` | `INT UNSIGNED AUTO_INCREMENT` | Clave primaria. Los códigos no pueden ser negativos. |
| `OBRA.nombre` | `VARCHAR(150)` | Longitud suficiente para títulos largos. |
| `OBRA.fecha_obra` | `DATETIME` | Una función tiene fecha **y hora**. Así una función de hoy en la noche sigue a la venta durante el día. |
| `OBRA.aforo`, `OBRA.disponibles` | `SMALLINT UNSIGNED` | Hasta 65 535 butacas. `UNSIGNED` impide valores negativos. |
| `OBRA.sala` | `VARCHAR(50)` | Nombre de la sala. |
| `VENTAS.numero_venta` | `INT UNSIGNED AUTO_INCREMENT` | Número de entrada autoincremental, como pide el enunciado. |
| `VENTAS.cod_obra` | `INT UNSIGNED` + clave foránea | Integridad referencial con `OBRA`. No se puede borrar una obra que tiene ventas. |
| `VENTAS.comprador` | `VARCHAR(20)` | Identificador del comprador, ya normalizado. |
| `VENTAS.fecha_compra` | `DATETIME DEFAULT CURRENT_TIMESTAMP` | Momento de la compra. |

Además se agregaron restricciones `CHECK` (`aforo > 0`, `disponibles <= aforo`)
y un índice `(fecha_obra, disponibles)` para la consulta de la cartelera.

### Compra sin sobreventa

La venta se registra en una transacción. Primero se descuenta la entrada con un
`UPDATE` condicional:

```sql
UPDATE OBRA SET disponibles = disponibles - 1
 WHERE cod_obra = ? AND disponibles > 0 AND fecha_obra > NOW();
```

Solo si se actualizó la fila se inserta la venta y se confirma la transacción.
Si dos personas compran la última entrada al mismo tiempo, InnoDB serializa las
dos actualizaciones y solo una de ellas encuentra entradas. La otra recibe un
mensaje claro y no se registra nada. Esto se probó con 20 compras simultáneas
por la última entrada: hubo exactamente una venta.

### Identificador del comprador

El enunciado no define su formato. Se interpreta como un documento de identidad
de 5 a 20 caracteres con letras, números y guiones. Antes de validarlo se quitan
los espacios y los puntos y se pasa a mayúsculas, así que `v-12.345.678` se
guarda como `V-12345678`.

### Seguridad y robustez

- Todas las consultas usan sentencias preparadas (PDO), lo que evita la inyección SQL.
- Toda salida se escapa con `htmlspecialchars`, lo que evita XSS. También se envía una cabecera `Content-Security-Policy`.
- Cada formulario lleva un token de un solo uso ligado a la sesión y a la obra. Protege contra CSRF y evita compras duplicadas por doble clic o reenvío.
- Se aplica el patrón POST → Redirect → GET, así que refrescar la confirmación no repite la compra.
- La página de confirmación solo muestra las entradas compradas en la propia sesión.
- Los errores nunca se muestran al usuario: se registran en el log del servidor y se presenta una página amigable.
- La regla "fecha mayor que la actual" la evalúa siempre MySQL (`NOW()`), así no depende de la zona horaria configurada en PHP.
- Las carpetas `includes/` y `database/` incluyen un `.htaccess` que bloquea el acceso directo en Apache.

## Estructura

```
├── index.php              Cartelera (obras disponibles)
├── comprar.php            Formulario y registro de la compra
├── confirmacion.php       Número de entrada y detalle de la compra
├── includes/
│   ├── bootstrap.php      Arranque: errores, cabeceras y sesión
│   ├── config.php         Configuración (conexión a la base)
│   ├── db.php             Conexión PDO
│   ├── obras.php          Consultas y registro de ventas
│   ├── sesion.php         Sesión y tokens de compra
│   ├── helpers.php        Utilidades (escape, fechas, validación)
│   └── layout.php         Cabecera, pie y páginas de mensaje
├── assets/                CSS y JavaScript (mejora progresiva)
└── database/teatro.sql    Respaldo de la base de datos
```
