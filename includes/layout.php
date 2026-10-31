<?php

declare(strict_types=1);

function render_cabecera(string $titulo): void
{
    ?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titulo) ?> · Teatro</title>
    <link rel="stylesheet" href="<?= e(url('assets/css/estilos.css')) ?>">
</head>
<body>
    <header class="cabecera">
        <div class="contenedor cabecera__contenido">
            <a class="marca" href="<?= e(url('index.php')) ?>">
                <span class="marca__icono" aria-hidden="true">🎭</span>
                <span>Teatro</span>
            </a>
            <nav aria-label="Principal">
                <a class="cabecera__enlace" href="<?= e(url('index.php')) ?>">Obras disponibles</a>
            </nav>
        </div>
    </header>
    <main class="contenedor principal" id="contenido">
    <?php
}

function render_pie(): void
{
    ?>
    </main>
    <footer class="pie">
        <div class="contenedor">
            <p>Teatro · Venta de entradas en línea</p>
        </div>
    </footer>
</body>
</html>
    <?php
}

/**
 * Página completa de mensaje (errores, recursos no encontrados, etc.).
 */
function render_pagina_mensaje(int $codigoHttp, string $titulo, string $mensaje, ?string $detalle = null): void
{
    if (!headers_sent()) {
        http_response_code($codigoHttp);
    }

    render_cabecera($titulo);
    ?>
    <section class="tarjeta mensaje">
        <h1><?= e($titulo) ?></h1>
        <p><?= e($mensaje) ?></p>
        <?php if ($detalle !== null): ?>
            <pre class="mensaje__detalle"><?= e($detalle) ?></pre>
        <?php endif; ?>
        <a class="boton" href="<?= e(url('index.php')) ?>">Volver a las obras disponibles</a>
    </section>
    <?php
    render_pie();
}
