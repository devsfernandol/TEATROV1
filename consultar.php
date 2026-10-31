<?php

declare(strict_types=1);

require __DIR__ . '/includes/bootstrap.php';

/*
 * Permite volver a ver una entrada desde cualquier navegador (por ejemplo,
 * después de cerrar el que se usó para comprar) con su número de entrada y
 * el identificador del comprador. Se exigen los dos datos para que nadie
 * pueda ver entradas ajenas probando números, y los intentos por IP están
 * limitados para impedir adivinarlos por fuerza bruta.
 */

$error = null;
$numeroIngresado = '';
$identificadorIngresado = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $numeroRecibido = $_POST['numero'] ?? '';
    $identificadorRecibido = $_POST['identificador'] ?? '';
    $numeroIngresado = is_string($numeroRecibido) ? substr(trim($numeroRecibido), 0, 12) : '';
    $identificadorIngresado = is_string($identificadorRecibido) ? substr(trim($identificadorRecibido), 0, 30) : '';

    $numeroVenta = entero_positivo($numeroIngresado);
    $identificador = normalizar_identificador($identificadorIngresado);

    if (!navegador_envio_cookie_de_sesion()) {
        $error = 'Su navegador no está aceptando cookies. Habilítelas para poder ver su entrada.';
        http_response_code(400);
    } elseif ($numeroVenta === null || !identificador_valido($identificador)) {
        $error = 'Ingrese su número de entrada y el identificador con el que hizo la compra.';
        http_response_code(422);
    } elseif (!consumir_intento('consulta', config()['limites']['consultas_por_ip'], 900)) {
        error_log('[TEATRO-AVISO] Límite de consultas por IP alcanzado: ' . ($_SERVER['REMOTE_ADDR'] ?? ''));
        render_pagina_mensaje(
            429,
            'Demasiadas consultas',
            'Se alcanzó el máximo de consultas permitidas desde su conexión. Espere 15 minutos y vuelva a intentarlo.'
        );
        exit;
    } else {
        $venta = obtener_venta(db(), $numeroVenta);

        if ($venta !== null && hash_equals($venta['comprador'], $identificador)) {
            // Nuevo identificador de sesión al dar acceso a la entrada (evita la fijación de sesión).
            session_regenerate_id(true);
            recordar_venta_en_sesion($numeroVenta);
            redirigir('confirmacion.php?venta=' . $numeroVenta);
        }

        $error = 'No encontramos una entrada con ese número e identificador. Revise los datos e inténtelo de nuevo.';
        http_response_code(404);
    }
}

render_cabecera('Consultar mi entrada');
?>
<p class="volver"><a href="<?= e(url('index.php')) ?>">← Volver a las obras disponibles</a></p>

<section class="tarjeta consulta" aria-labelledby="titulo-consulta">
    <h1 id="titulo-consulta">Consultar mi entrada</h1>
    <p>Escriba el número de entrada que recibió al comprar y el identificador con el que hizo la compra.</p>

    <?php if ($error !== null): ?>
        <div class="alerta alerta--error" role="alert" id="error-consulta"><?= e($error) ?></div>
    <?php endif; ?>

    <form method="post" action="<?= e(url('consultar.php')) ?>" class="formulario" novalidate>
        <div class="campo">
            <label for="numero">Número de entrada</label>
            <input
                type="text"
                id="numero"
                name="numero"
                value="<?= e($numeroIngresado) ?>"
                maxlength="12"
                inputmode="numeric"
                autocomplete="off"
                required
                <?= $error !== null ? 'aria-invalid="true" aria-describedby="error-consulta" autofocus' : '' ?>
            >
        </div>

        <div class="campo">
            <label for="identificador">Identificador</label>
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
                aria-describedby="ayuda-identificador"
                <?= $error !== null ? 'aria-invalid="true"' : '' ?>
            >
            <p class="campo__ayuda" id="ayuda-identificador">El mismo documento que usó al comprar. Ejemplo: V-12345678.</p>
        </div>

        <button type="submit" class="boton boton--bloque">Ver mi entrada</button>
    </form>
</section>
<?php
render_pie();
