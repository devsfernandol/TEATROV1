<?php

declare(strict_types=1);

require __DIR__ . '/includes/bootstrap.php';

$numeroVenta = entero_positivo($_GET['venta'] ?? null);

// Solo se muestran las entradas compradas en esta misma sesión.
$venta = ($numeroVenta !== null && venta_pertenece_a_sesion($numeroVenta))
    ? obtener_venta(db(), $numeroVenta)
    : null;

if ($venta === null) {
    render_pagina_mensaje(
        404,
        'Entrada no encontrada',
        'No encontramos la entrada solicitada. Si la compró en otro navegador o lo cerró, puede verla en «Consultar mi entrada» con su número de entrada y su identificador.'
    );
    exit;
}

render_cabecera('Compra realizada');
?>
<section class="tarjeta entrada" aria-labelledby="titulo-confirmacion">
    <div class="alerta alerta--exito" role="status">
        <h1 id="titulo-confirmacion">¡Compra realizada con éxito!</h1>
        <p>Conserve su número de entrada. Con él y su identificador puede volver a ver esta entrada desde cualquier navegador en «Consultar mi entrada».</p>
    </div>

    <div class="entrada__numero">
        <span class="entrada__numero-etiqueta">Número de entrada</span>
        <strong class="entrada__numero-valor"><?= e($venta['numero_venta']) ?></strong>
    </div>

    <dl class="obra__datos entrada__datos">
        <div>
            <dt>Obra</dt>
            <dd><?= e($venta['nombre']) ?></dd>
        </div>
        <div>
            <dt>Fecha de la obra</dt>
            <dd><time datetime="<?= e(fecha_iso($venta['fecha_obra'])) ?>"><?= e(formatear_fecha($venta['fecha_obra'])) ?></time></dd>
        </div>
        <div>
            <dt>Sala</dt>
            <dd><?= e($venta['sala']) ?></dd>
        </div>
        <div>
            <dt>Comprador</dt>
            <dd><?= e($venta['comprador']) ?></dd>
        </div>
        <div>
            <dt>Fecha de compra</dt>
            <dd><time datetime="<?= e(fecha_iso($venta['fecha_compra'])) ?>"><?= e(formatear_fecha($venta['fecha_compra'])) ?></time></dd>
        </div>
    </dl>

    <div class="entrada__acciones">
        <a class="boton" href="<?= e(url('index.php')) ?>">Volver a las obras disponibles</a>
    </div>
</section>
<?php
render_pie();
