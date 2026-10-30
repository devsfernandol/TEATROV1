# Herramientas de desarrollo

Esta carpeta no forma parte de la entrega: `dev/empaquetar.sh` la excluye.

| Script | Qué hace |
|---|---|
| `dev/iniciar.sh` | Levanta un MySQL propio del proyecto (127.0.0.1:3307, datos en `.dev/`, sin `sudo`) y la aplicación en http://localhost:8000 |
| `dev/pruebas.sh [url]` | Ejecuta las pruebas de punta a punta (compra, validaciones, doble envío, concurrencia, integridad). Restaura la base antes y después. |
| `dev/reiniciar-bd.sh` | Restaura la base `TEATRO` desde `database/teatro.sql` |
| `dev/detener.sh` | Detiene el MySQL del proyecto (los datos se conservan) |
| `dev/empaquetar.sh [ref]` | Genera `dist/teatro.zip` para la entrega a partir de un commit |

El MySQL del proyecto no toca el MySQL ni el Apache instalados en el sistema.
