<?php

declare(strict_types=1);

/**
 * Devuelve la configuración de la aplicación (se carga una sola vez).
 */
function config(): array
{
    static $config = null;

    if ($config === null) {
        $config = require __DIR__ . '/config.php';
    }

    return $config;
}

/**
 * Escapa un valor para imprimirlo de forma segura en HTML.
 */
function e(string|int|null $valor): string
{
    return htmlspecialchars((string) $valor, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/**
 * Redirige con 303 (See Other) para aplicar el patrón POST/Redirect/GET.
 */
function redirigir(string $url): void
{
    header('Location: ' . $url, true, 303);
    exit;
}

/**
 * Convierte un valor recibido por la petición en un entero positivo
 * dentro del rango de INT UNSIGNED, o null si no es válido.
 */
function entero_positivo(mixed $valor): ?int
{
    if (!is_string($valor) && !is_int($valor)) {
        return null;
    }

    $entero = filter_var($valor, FILTER_VALIDATE_INT, [
        'options' => ['min_range' => 1, 'max_range' => 4294967295],
    ]);

    return $entero === false ? null : $entero;
}

/**
 * Formatea una fecha DATETIME de MySQL en español, por ejemplo:
 * "sábado 7 de noviembre de 2026, 20:00 h".
 */
function formatear_fecha(string $fechaHora): string
{
    $fecha = DateTimeImmutable::createFromFormat('Y-m-d H:i:s', $fechaHora);
    if ($fecha === false) {
        return $fechaHora;
    }

    $dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    $meses = [
        1 => 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    return sprintf(
        '%s %d de %s de %d, %s h',
        $dias[(int) $fecha->format('w')],
        (int) $fecha->format('j'),
        $meses[(int) $fecha->format('n')],
        (int) $fecha->format('Y'),
        $fecha->format('H:i')
    );
}

/**
 * Formatea el número de entrada para mostrarlo al comprador (ej. 000042).
 */
function formatear_numero_entrada(int $numeroVenta): string
{
    return str_pad((string) $numeroVenta, 6, '0', STR_PAD_LEFT);
}

/**
 * Normaliza el identificador del comprador: quita espacios y puntos
 * y lo pasa a mayúsculas ("v-12.345.678" => "V-12345678").
 */
function normalizar_identificador(string $identificador): string
{
    return strtoupper(str_replace([' ', '.'], '', trim($identificador)));
}

/**
 * Valida un identificador ya normalizado: de 5 a 20 caracteres, solo letras
 * sin acentos, dígitos y guiones, sin empezar ni terminar en guion.
 */
function identificador_valido(string $identificador): bool
{
    return preg_match('/^[A-Z0-9][A-Z0-9-]{3,18}[A-Z0-9]$/', $identificador) === 1;
}
