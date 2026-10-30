# Teatro · Venta de entradas en línea

Solución a la prueba técnica PHP + MySQL. Los usuarios ven las obras de teatro
disponibles, eligen una, ingresan su identificador y reciben su número de entrada.

## Requisitos

- PHP 7.4 o superior (probado en PHP 8.1) con la extensión `pdo_mysql`, que viene
  incluida en XAMPP, WAMP y Laragon.
- MySQL 5.7 o superior, o MariaDB 10.3 o superior, con el motor InnoDB.
- Un servidor web con PHP, como Apache (por ejemplo, el de XAMPP).

## Instalación

1. **Copiar los archivos** a una carpeta del servidor web, por ejemplo
   `C:\xampp\htdocs\teatro` (XAMPP) o `/var/www/html/teatro` (Linux).

2. **Restaurar la base de datos** desde `database/teatro.sql`. El script crea el
   esquema `TEATRO`, sus tablas y datos de prueba. Puede hacerse de dos formas:

   - **phpMyAdmin:** pestaña *Importar*, seleccionar `database/teatro.sql` y pulsar *Importar*.
   - **Consola:** `mysql -u root -p < database/teatro.sql`

3. **Revisar la conexión.** Por defecto se usa el servidor `localhost`, el puerto
   `3306`, el usuario `root` y la contraseña vacía, que es la configuración de
   fábrica de XAMPP. **Si sus credenciales son esas, no hace falta cambiar nada.**
   Si son distintas, copie `includes/config.local.example.php` como
   `includes/config.local.php` y escriba ahí sus datos.

4. **Abrir** `http://localhost/teatro/` en el navegador.

> Las fechas de los datos de prueba se calculan a partir del momento en que se
> restaura el script, así que siempre habrá obras futuras disponibles para probar.
> Para volver al estado inicial basta con importar el script de nuevo.

## Funcionamiento

1. **`index.php`** muestra todas las obras disponibles: las que todavía tienen
   entradas (`disponibles > 0`) y cuya fecha es mayor que la actual
   (`fecha_obra > NOW()`).
2. Al seleccionar una obra, **`comprar.php`** pide el identificador del comprador.
3. Al confirmar, en una sola transacción:
   - se inserta la venta en **`VENTAS`**, donde `numero_venta` es autoincremental, y
   - se resta uno a `disponibles` en **`OBRA`**.
4. **`confirmacion.php`** muestra al usuario su número de entrada, que es el
   `numero_venta` generado.

## Datos de prueba

| Obra | Situación | ¿Aparece en la lista? |
|---|---|---|
| La casa de Bernarda Alba | 120 de 120 disponibles | Sí |
| Bodas de sangre | 78 de 80 disponibles | Sí |
| La vida es sueño | 2 de 5 disponibles | Sí, hasta que se vendan las 2 |
| Don Juan Tenorio | 200 de 200 disponibles | Sí |
| El sí de las niñas | 60 de 60 disponibles | Sí |
| Luces de bohemia | Agotada (0 de 3) | **No** |
| Fuenteovejuna | Su fecha ya pasó | **No** |

La tabla `VENTAS` trae 10 ventas previas, así que la primera compra que se haga
genera la entrada número **11**.

## Cómo probar

| Acción | Resultado esperado |
|---|---|
| Abrir la página principal | Aparecen 5 obras. *Luces de bohemia* y *Fuenteovejuna* no aparecen. |
| Comprar una entrada | Se muestra el número de entrada. En la base, la venta aparece en `VENTAS` y `disponibles` de la obra bajó en uno. |
| Comprar las 2 últimas entradas de *La vida es sueño* | La obra deja de aparecer en la lista. |
| Dejar el identificador vacío o escribir uno inválido (`ab`, `<script>`) | Se muestra un mensaje y no se registra ninguna venta. |
| Refrescar (F5) la página de confirmación o pulsar dos veces "Comprar entrada" | No se genera una segunda venta. |
| Abrir `comprar.php?obra=6`, `?obra=7`, `?obra=999` o `?obra=abc` | Se muestra el mensaje "Obra no disponible". |

Consultas para verificar en la base:

```sql
SELECT * FROM TEATRO.OBRA;
SELECT * FROM TEATRO.VENTAS ORDER BY numero_venta DESC;
```

## Decisiones de diseño

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
registra nada. Se probó con 20 compras simultáneas por las 2 últimas entradas:
hubo exactamente 2 ventas.

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

## Estructura

```
├── index.php              Obras disponibles (página principal)
├── comprar.php            Pide el identificador y registra la venta
├── confirmacion.php       Muestra el número de entrada
├── includes/
│   ├── bootstrap.php      Arranque: manejo de errores, cabeceras y sesión
│   ├── config.php         Datos de conexión a la base
│   ├── db.php             Conexión PDO
│   ├── obras.php          Consultas de obras y registro de ventas
│   ├── sesion.php         Sesión y token del formulario de compra
│   ├── helpers.php        Utilidades (escape, fechas, validación)
│   └── layout.php         Cabecera, pie y páginas de mensaje
├── assets/                Estilos y JavaScript (opcional: todo funciona sin JS)
└── database/teatro.sql    Respaldo de la base de datos TEATRO
```
