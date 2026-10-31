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

// Límite numérico desde una variable de entorno. A diferencia de "?:", respeta el 0 (sin límite).
$limiteDeEntorno = static function (string $variable, int $porDefecto): int {
    $valor = getenv($variable);

    return ($valor === false || $valor === '') ? $porDefecto : (int) $valor;
};

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

    // Protección contra compras masivas (bots) y contra adivinar entradas ajenas.
    'limites' => [
        // Entradas que una misma persona (identificador) puede comprar para una obra.
        'entradas_por_comprador' => $limiteDeEntorno('TEATRO_LIMITE_ENTRADAS_COMPRADOR', 4),
        // Compras por dirección IP en una hora.
        'compras_por_ip'         => $limiteDeEntorno('TEATRO_LIMITE_COMPRAS_IP', 20),
        // Consultas de entradas por dirección IP en 15 minutos.
        'consultas_por_ip'       => $limiteDeEntorno('TEATRO_LIMITE_CONSULTAS_IP', 10),
        // Carpeta donde se lleva la cuenta (por defecto, la temporal del sistema).
        'directorio'             => getenv('TEATRO_LIMITES_DIR') ?: sys_get_temp_dir() . '/teatro-limites',
    ],
];

$archivoLocal = __DIR__ . '/config.local.php';
if (is_file($archivoLocal)) {
    $configLocal = require $archivoLocal;
    if (is_array($configLocal)) {
        $config = array_replace_recursive($config, $configLocal);
    }
}

return $config;
