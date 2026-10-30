<?php

declare(strict_types=1);

require __DIR__ . '/includes/bootstrap.php';

$obras = obtener_obras_disponibles(db());

render_cabecera('Obras disponibles');
?>
<section class="encabezado-pagina">
    <h1>Obras disponibles</h1>
    <p>Seleccione una obra para comprar su entrada.</p>
</section>

<?php if ($obras === []): ?>
    <section class="tarjeta mensaje">
        <h2>No hay obras disponibles</h2>
        <p>En este momento no hay obras con entradas a la venta. Vuelva a consultar más adelante.</p>
    </section>
<?php else: ?>
    <ul class="cartelera">
        <?php foreach ($obras as $obra): ?>
            <li class="tarjeta obra">
                <h2 class="obra__nombre"><?= e($obra['nombre']) ?></h2>
                <dl class="obra__datos">
                    <div>
                        <dt>Fecha</dt>
                        <dd><time datetime="<?= e(fecha_iso($obra['fecha_obra'])) ?>"><?= e(formatear_fecha($obra['fecha_obra'])) ?></time></dd>
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
                <a class="boton obra__accion" href="<?= e(url('comprar.php?obra=' . $obra['cod_obra'])) ?>">
                    Comprar entrada<span class="solo-lectores"> para <?= e($obra['nombre']) ?></span>
                </a>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
<?php
render_pie();
