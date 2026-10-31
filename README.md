# Teatro · Venta de entradas en línea

Solución a la prueba técnica PHP + MySQL: lista de obras disponibles, compra
de entradas con número de entrada autoincremental y actualización de `VENTAS`
y `OBRA` en una sola transacción.

| Documento | Para quién |
|---|---|
| [`LEAME.md`](LEAME.md) | **Evaluador:** requisitos, instalación, cómo probar y decisiones de diseño. Se incluye en la entrega. |
| [`dev/README.md`](dev/README.md) | **Desarrollo:** entorno aislado (PHP 8.5.12 + MySQL sin `sudo`), pruebas automatizadas y empaquetado. |

Inicio rápido para desarrollo (Linux / WSL):

```bash
dev/iniciar.sh                # http://localhost:8000
dev/pruebas.sh                # 104 pruebas funcionales (en otra terminal)
dev/prueba-instalacion.sh     # instalación desde cero del paquete de entrega
```
