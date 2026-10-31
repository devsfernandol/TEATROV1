# Teatro · Venta de entradas en línea

Solución a la prueba técnica de PHP + MySQL. El usuario ve las obras de teatro
disponibles, elige una, escribe su identificador y recibe su número de entrada.

Hecho en **PHP sin frameworks**, **MySQL** y **HTML/CSS**, sin JavaScript. Se
instala en **Linux con Docker** mediante un instalador con menú.

- Instrucciones de la entrega: [LEAME.md](LEAME.md)
- Guía paso a paso: [GUIA-INSTALACION.pdf](GUIA-INSTALACION.pdf)

## Instalación

```bash
unzip teatro-v1.3.zip && cd teatro      # o: git clone ... && cd teatro
sudo ./instalar.sh
```

```
  1) Instalar con un MySQL nuevo, en Docker (recomendado: no necesita nada más)
  2) Instalar usando un MySQL que ya existe (pide sus credenciales)
  3) Ver el estado
  4) Desinstalar
  0) Salir
```

- **Opción 1.** Levanta Nginx, PHP 8.5 y MySQL 8.4. La base se importa sola y
  el usuario `teatro_app` recibe una clave aleatoria.
- **Opción 2.** Se conecta a un MySQL existente y se adapta a dónde está:
  - en el mismo servidor, por su socket, sin abrirlo a la red;
  - en otro servidor, por IP y puerto.

  Importa la base `TEATRO` (o conserva la que ya tenga) y crea `teatro_app` con
  permisos mínimos. Las credenciales de administrador no se guardan.

## Qué pide la prueba y dónde está

| Lo que pide el enunciado | Dónde está |
|---|---|
| Base `TEATRO` con `OBRA` y `VENTAS` | `database/teatro.sql` (también es el respaldo) |
| Página `index` con las obras con entradas y fecha futura | `index.php` |
| Pedir el identificador y registrar la venta con número autoincremental | `comprar.php` → `confirmacion.php` |
| Restar 1 a `disponibles` | `includes/obras.php`, en la misma transacción que la venta |
| Archivo LEAME | `LEAME.md` |
| Producción sin errores | `instalar.sh` + Docker y [pruebas automáticas](#pruebas-automáticas) |

```
index.php  ──"Comprar entrada"──▶  comprar.php  ──identificador──▶  confirmacion.php
consultar.php  ──número + identificador──▶  confirmacion.php   (desde otro navegador)
```

## Desarrollo

La carpeta `dev/` tiene un entorno para **Linux o WSL** con su propio PHP
8.5.12 y su propio MySQL en `.dev/`, sin `sudo`. No va en el paquete de entrega.

```bash
sudo apt install build-essential libssl-dev zlib1g-dev mysql-server curl python3   # una vez
dev/iniciar.sh            # http://localhost:8000 · MySQL en 127.0.0.1:3307
dev/detener.sh            # detiene MySQL (los datos se conservan)
```

### Pruebas automáticas

| Script | Qué comprueba |
|---|---|
| `dev/pruebas.sh` | **131 pruebas** de punta a punta: lista de obras, compra, validación, seguridad (CSRF, XSS, inyección SQL, cabeceras, cookie), doble envío, consultar entrada, concurrencia (20 compras simultáneas por 2 entradas), bloqueos de MySQL, integridad y log sin errores. |
| `dev/prueba-instalacion.sh` | **96 comprobaciones**: genera el ZIP, revisa que tenga lo necesario y nada más, lo instala en una carpeta limpia, importa la base dos veces, ejecuta las 131 pruebas sobre esa copia y prueba los límites por IP, la conexión por socket y que con MySQL caído no se vea ningún error técnico. Con `PHP_BIN=/usr/bin/php` prueba con otro PHP (8.1). |
| `dev/prueba-docker.sh usuario@servidor` | **54 comprobaciones** del instalador en un Linux con Docker real: los tres modos (Docker, socket y red), una clave incorrecta, actualizar conservando datos, empezar de cero, MySQL caído, archivos internos con 404, permisos de `.env` y desinstalar. Usa un proyecto y un puerto propios, sin tocar otras instalaciones. |

`dev/prueba-instalacion.sh` y `dev/prueba-docker.sh` usan el **último commit**.

| Otros scripts | |
|---|---|
| `dev/reiniciar-bd.sh` | Restaura la base desde `database/teatro.sql` |
| `dev/empaquetar.sh [ref]` | Genera `dist/teatro.zip` (la entrega) |
| `dev/generar-guia.sh` | Regenera `GUIA-INSTALACION.pdf` desde `dev/guia/guia.html` |

`deploy/` es el despliegue de la demo en línea del autor, detrás de un túnel de
Cloudflare; tampoco va en la entrega.

## Estructura

```
├── index.php, comprar.php, confirmacion.php, consultar.php   Páginas
├── includes/            Configuración, conexión, consultas, sesión, límites, plantillas
├── assets/css/          Estilos
├── database/teatro.sql  Esquema y datos de prueba
├── instalar.sh          Instalador con menú
├── docker-compose.yml   Nginx + PHP
├── docker/              mysql-docker.yml, mysql-socket.yml, Nginx, PHP y ayudante del instalador
├── LEAME.md, GUIA-INSTALACION.pdf
├── dev/                 Entorno de desarrollo, pruebas y guía (no va en la entrega)
└── deploy/              Demo en línea del autor (no va en la entrega)
```
