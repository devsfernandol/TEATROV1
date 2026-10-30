<?php

declare(strict_types=1);

/**
 * Configuración de la aplicación.
 *
 * Los valores se toman, en este orden de prioridad, de:
 *   1. includes/config.local.php (opcional, no versionado), que debe retornar un arreglo.
 *   2. Variables de entorno (TEATRO_DB_HOST, TEATRO_DB_PORT, ...).
 *   3. Los valores por defecto de este archivo.
 */

$config = [
    'db' => [
        'host'     => getenv('TEATRO_DB_HOST') ?: 'localhost',
        'port'     => (int) (getenv('TEATRO_DB_PORT') ?: 3306),
        'name'     => getenv('TEATRO_DB_NAME') ?: 'TEATRO',
        'user'     => getenv('TEATRO_DB_USER') ?: 'root',
        'password' => getenv('TEATRO_DB_PASSWORD') ?: '',
    ],
    // Nunca activar en producción: muestra el detalle técnico de los errores.
    'debug' => filter_var(getenv('TEATRO_DEBUG') ?: false, FILTER_VALIDATE_BOOLEAN),
];

$archivoLocal = __DIR__ . '/config.local.php';
if (is_file($archivoLocal)) {
    $configLocal = require $archivoLocal;
    if (is_array($configLocal)) {
        $config = array_replace_recursive($config, $configLocal);
    }
}

return $config;
