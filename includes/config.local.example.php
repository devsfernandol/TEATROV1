<?php

/**
 * Ejemplo de configuración local.
 *
 * Copie este archivo como includes/config.local.php y ajuste solo los valores
 * que necesite cambiar; el resto se toma de includes/config.php.
 */

return [
    'db' => [
        'host'     => 'localhost',
        'port'     => 3306,
        'user'     => 'root',
        'password' => '',
    ],

    // Protección contra compras masivas (0 = sin límite). Para hacer muchas
    // compras de prueba desde un mismo equipo, suba compras_por_ip.
    // 'limites' => [
    //     'entradas_por_comprador' => 4,   // entradas por persona para cada obra
    //     'compras_por_ip'         => 20,  // compras por IP en una hora
    //     'consultas_por_ip'       => 10,  // consultas de entradas por IP en 15 minutos
    // ],

    // Muestra el detalle técnico de los errores en pantalla. Solo para
    // diagnosticar un problema de instalación: nunca en producción.
    // 'debug' => true,
];
