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

    // Muestra el detalle técnico de los errores en pantalla. Solo para
    // diagnosticar un problema de instalación: nunca en producción.
    // 'debug' => true,
];
