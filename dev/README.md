# Guía de desarrollo y pruebas

Esta carpeta tiene las herramientas para desarrollar y probar el sistema en
Linux o WSL. **No forma parte de la entrega:** `dev/empaquetar.sh` la excluye.
Las instrucciones para el evaluador están en [`LEAME.md`](../LEAME.md).

El entorno es **aislado**: usa un MySQL y un PHP propios del proyecto, guardados
en `.dev/` (fuera de git). No necesita `sudo` ni contraseñas, y no toca el MySQL,
el PHP ni el Apache instalados en el sistema.

| | Entorno del proyecto |
|---|---|
| PHP | 8.5.12, compilado desde el código fuente oficial de php.net (SHA-256 verificado) |
| MySQL | El `mysqld` del sistema, con datos propios en `.dev/mysql`, escuchando en `127.0.0.1:3307` |
| Aplicación | `http://localhost:8000`, con 8 procesos en paralelo (concurrencia real) |
| Usuario de la base | `teatro_app` / `teatro_dev`, con permisos solo sobre `TEATRO` (credenciales de desarrollo) |

## 1. Requisitos (una sola vez)

Paquetes de Ubuntu necesarios: compilador, librerías para compilar PHP y los
binarios de MySQL.

```bash
sudo apt install build-essential libssl-dev zlib1g-dev mysql-server curl python3
```

En la máquina actual ya están todos instalados. Si `sudo` pide una contraseña
que no recuerda, en WSL puede ejecutarse como root desde PowerShell de Windows:
`wsl -u root apt install ...`

## 2. Levantar el entorno

```bash
dev/iniciar.sh
```

La primera vez tarda unos minutos, porque compila PHP 8.5.12 e inicializa
MySQL. Las siguientes veces arranca en segundos. Al terminar muestra:

```
→ PHP 8.5.12 (cli) ...
→ Aplicación disponible en http://localhost:8000  (Ctrl+C para detener)
```

Abra **http://localhost:8000** en el navegador de Windows.

`Ctrl+C` detiene la aplicación, pero MySQL sigue activo. Para detener MySQL:

```bash
dev/detener.sh
```

## 3. Probar

Con el entorno levantado, en **otra terminal**:

### Pruebas funcionales: `dev/pruebas.sh` (unos 30 segundos)

Ejecuta 104 pruebas de punta a punta contra la aplicación en marcha:

- **Lista de obras:** solo aparecen las disponibles, ordenadas por fecha y con sus datos.
- **Seguridad:** cabeceras HTTP, cookie de sesión, CSRF, XSS e inyección SQL.
- **Validación:** parámetros inválidos, identificadores inválidos y extremos (20 000 caracteres, bytes no UTF-8, arreglos) e identificadores válidos en los límites.
- **Compra:** la venta se registra en `VENTAS`, `disponibles` baja en uno y se muestra el número de entrada.
- **Doble envío y privacidad:** F5, doble clic y entradas ajenas.
- **Concurrencia:** 20 compras simultáneas por 2 entradas, el mismo formulario enviado 10 veces a la vez, dos pestañas y el mismo identificador desde 5 navegadores.
- **Bloqueos de MySQL:** la compra se reintenta automáticamente.
- **Integridad:** `disponibles = aforo − ventas` en todas las obras.
- **Log de PHP:** sin errores ni avisos.

La base se restaura antes y después, así que puede ejecutarse las veces que haga falta.

### Prueba de instalación: `dev/prueba-instalacion.sh` (alrededor de 1 minuto)

Simula exactamente lo que hará el evaluador:

1. Genera el ZIP de entrega desde el último commit y revisa que incluya lo necesario y nada más.
2. Lo descomprime en una carpeta limpia, dentro de una subcarpeta `/teatro/`.
3. Importa `database/teatro.sql` dos veces y verifica que el esquema coincida con el enunciado.
4. Ejecuta las 104 pruebas funcionales sobre esa copia.
5. Comprueba que, con MySQL caído o con credenciales incorrectas, el usuario ve
   una página amigable sin datos técnicos y el detalle queda en el log.

> Usa el **último commit**, no la copia de trabajo. Confirme los cambios antes de ejecutarla.

### Prueba manual en el navegador

El recorrido del apartado *Cómo probar la solución* de [`LEAME.md`](../LEAME.md)
se puede seguir en http://localhost:8000. Para dejar los datos como al principio:

```bash
dev/reiniciar-bd.sh
```

## 4. Entregar

```bash
dev/prueba-instalacion.sh   # verificar el paquete completo
dev/empaquetar.sh           # genera dist/teatro.zip
```

`dist/teatro.zip` contiene la carpeta `teatro/` con las páginas, `includes/`,
`assets/`, `database/teatro.sql` y `LEAME.md`.

## Referencia de scripts

| Script | Qué hace |
|---|---|
| `dev/iniciar.sh` | Instala PHP si falta, levanta MySQL y sirve la aplicación en el puerto 8000 |
| `dev/detener.sh` | Detiene el MySQL del proyecto (los datos se conservan) |
| `dev/reiniciar-bd.sh` | Restaura la base `TEATRO` desde `database/teatro.sql` |
| `dev/pruebas.sh [url]` | Pruebas funcionales (por defecto contra http://localhost:8000) |
| `dev/prueba-instalacion.sh [ref]` | Instalación desde cero del paquete y todas las pruebas |
| `dev/empaquetar.sh [ref]` | Genera `dist/teatro.zip` desde un commit o etiqueta |
| `dev/instalar-php.sh [versión]` | Compila PHP en `.dev/php` (lo llama `iniciar.sh`) |

Para empezar de cero (borra los datos del MySQL de desarrollo y el PHP compilado):

```bash
dev/detener.sh && rm -rf .dev && dev/iniciar.sh
```
