<?php

declare(strict_types=1);

require __DIR__ . '/includes/bootstrap.php';

$pdo = db();
$error = null;
$identificadorIngresado = '';
$token = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $tokenRecibido = $_POST['token'] ?? null;
    $datosToken = obtener_token_compra($tokenRecibido);

    $identificadorRecibido = $_POST['identificador'] ?? '';
    $identificadorIngresado = is_string($identificadorRecibido) ? substr(trim($identificadorRecibido), 0, 30) : '';

    if ($datosToken === null) {
        // Token inexistente o expirado: se vuelve a mostrar el formulario con uno nuevo.
        $codObra = entero_positivo($_GET['obra'] ?? null);
        $error = 'Su sesión expiró o el formulario ya no es válido. Por favor, vuelva a intentarlo.';
        http_response_code(400);
    } elseif ($datosToken['numero_venta'] !== null) {
        // El formulario ya fue procesado (doble envío): no se genera otra venta.
        redirigir('confirmacion.php?venta=' . $datosToken['numero_venta']);
    } else {
        $token = $tokenRecibido;
        $codObra = $datosToken['cod_obra'];
        $identificador = normalizar_identificador($identificadorIngresado);

        if ($identificador === '') {
            $error = 'Ingrese su identificador para continuar.';
        } elseif (!identificador_valido($identificador)) {
            $error = 'El identificador debe tener entre 5 y 20 caracteres y solo puede contener letras (sin acentos), números y guiones.';
        } else {
            try {
                $numeroVenta = registrar_venta($pdo, $codObra, $identificador);
            } catch (ObraNoDisponibleException) {
                render_pagina_mensaje(
                    409,
                    'Entradas no disponibles',
                    'Lo sentimos, las entradas de esta obra se agotaron mientras completaba la compra o la función ya no está a la venta. No se realizó ningún cargo.'
                );
                exit;
            }

            consumir_token_compra($token, $numeroVenta);
            redirigir('confirmacion.php?venta=' . $numeroVenta);
        }

        http_response_code(422);
    }
} else {
    $codObra = entero_positivo($_GET['obra'] ?? null);
}

$obra = $codObra === null ? null : obtener_obra_disponible($pdo, $codObra);

if ($obra === null) {
    render_pagina_mensaje(
        404,
        'Obra no disponible',
        'La obra que busca no existe, ya no tiene entradas o la función ya se realizó.'
    );
    exit;
}

$token ??= emitir_token_compra($obra['cod_obra']);

render_cabecera('Comprar entrada');
?>
<nav class="migas" aria-label="Ruta de navegación">
    <a href="index.php">Cartelera</a> <span aria-hidden="true">›</span> Comprar entrada
</nav>

<div class="compra">
    <section class="tarjeta compra__resumen" aria-labelledby="titulo-obra">
        <p class="sobretitulo">Está comprando una entrada para</p>
        <h1 id="titulo-obra"><?= e($obra['nombre']) ?></h1>
        <dl class="obra__datos">
            <div>
                <dt>Fecha</dt>
                <dd><time datetime="<?= e(str_replace(' ', 'T', $obra['fecha_obra'])) ?>"><?= e(formatear_fecha($obra['fecha_obra'])) ?></time></dd>
            </div>
            <div>
                <dt>Sala</dt>
                <dd><?= e($obra['sala']) ?></dd>
            </div>
            <div>
                <dt>Entradas disponibles</dt>
                <dd><?= e($obra['disponibles']) ?> de <?= e($obra['aforo']) ?></dd>
            </div>
        </dl>
    </section>

    <section class="tarjeta compra__formulario" aria-labelledby="titulo-formulario">
        <h2 id="titulo-formulario">Sus datos</h2>

        <?php if ($error !== null): ?>
            <div class="alerta alerta--error" role="alert" id="error-identificador"><?= e($error) ?></div>
        <?php endif; ?>

        <form method="post" action="comprar.php?obra=<?= e($obra['cod_obra']) ?>" class="formulario" data-envio-unico novalidate>
            <input type="hidden" name="token" value="<?= e($token) ?>">

            <div class="campo">
                <label for="identificador">Identificador (documento de identidad)</label>
                <input
                    type="text"
                    id="identificador"
                    name="identificador"
                    value="<?= e($identificadorIngresado) ?>"
                    maxlength="30"
                    autocomplete="off"
                    autocapitalize="characters"
                    spellcheck="false"
                    required
                    aria-describedby="ayuda-identificador<?= $error !== null ? ' error-identificador' : '' ?>"
                    <?= $error !== null ? 'aria-invalid="true" autofocus' : '' ?>
                >
                <p class="campo__ayuda" id="ayuda-identificador">
                    Entre 5 y 20 caracteres: letras, números y guiones. Ejemplo: V-12345678.
                </p>
            </div>

            <button type="submit" class="boton boton--bloque" data-texto-envio="Procesando compra…">
                Confirmar compra
            </button>
        </form>
    </section>
</div>
<?php
render_pie();
