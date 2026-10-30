<?php

declare(strict_types=1);

require __DIR__ . '/includes/bootstrap.php';

$obras = obtener_obras_disponibles(db());

render_cabecera('Cartelera');
?>
<section class="encabezado-pagina">
    <h1>Cartelera</h1>
    <p>Elija una obra para comprar su entrada.</p>
</section>

<?php if ($obras === []): ?>
    <section class="tarjeta mensaje">
        <h2>No hay obras disponibles</h2>
        <p>En este momento no hay funciones con entradas a la venta. Vuelva a consultar más adelante.</p>
    </section>
<?php else: ?>
    <ul class="cartelera">
        <?php foreach ($obras as $obra): ?>
            <?php $ultimas = $obra['disponibles'] <= max(5, intdiv($obra['aforo'], 10)); ?>
            <li class="tarjeta obra">
                <h2 class="obra__nombre"><?= e($obra['nombre']) ?></h2>
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
                        <dt>Entradas</dt>
                        <dd>
                            <?= e($obra['disponibles']) ?> de <?= e($obra['aforo']) ?> disponibles
                            <?php if ($ultimas): ?>
                                <span class="etiqueta etiqueta--alerta">¡Últimas!</span>
                            <?php endif; ?>
                        </dd>
                    </div>
                </dl>
                <a class="boton obra__accion" href="comprar.php?obra=<?= e($obra['cod_obra']) ?>">
                    Comprar entrada<span class="solo-lectores"> para <?= e($obra['nombre']) ?></span>
                </a>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
<?php
render_pie();
