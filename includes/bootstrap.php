<?php

declare(strict_types=1);

/**
 * Punto de arranque común a todas las páginas.
 *
 * El manejo de errores se configura antes de cargar cualquier otro archivo,
 * para que ningún error (ni siquiera uno de carga) llegue a mostrarse al usuario.
 */

// Los errores nunca se muestran al usuario: se registran en el log del servidor.
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
// Evita que los argumentos de las funciones (p. ej. la contraseña de la base) queden en las trazas.
ini_set('zend.exception_ignore_args', '1');

/**
 * Responde con una página de error amigable. Si la plantilla no está
 * disponible, responde con un texto plano equivalente.
 */
function responder_error_interno(?Throwable $e = null): void
{
    // Se descarta el HTML parcial que se hubiera generado antes del error.
    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    try {
        render_pagina_mensaje(
            500,
            'Servicio no disponible',
            'Ocurrió un problema al procesar su solicitud. Por favor, inténtelo de nuevo en unos minutos.',
            ($e !== null && config()['debug']) ? (string) $e : null
        );
    } catch (Throwable $errorAlMostrar) {
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: text/plain; charset=utf-8');
        }
        echo 'Servicio no disponible. Por favor, inténtelo de nuevo en unos minutos.';
    }
}

// Cualquier aviso o advertencia se trata como error para no continuar en un estado inconsistente.
// Los avisos de obsolescencia (versiones futuras de PHP) solo se registran en el log.
set_error_handler(static function (int $severidad, string $mensaje, string $archivo, int $linea): bool {
    if (!(error_reporting() & $severidad)) {
        return false;
    }
    if (($severidad & (E_DEPRECATED | E_USER_DEPRECATED)) !== 0) {
        error_log(sprintf('[TEATRO] Obsoleto: %s en %s:%d', $mensaje, $archivo, $linea));
        return true;
    }
    throw new ErrorException($mensaje, 0, $severidad, $archivo, $linea);
});

set_exception_handler(static function (Throwable $e): void {
    error_log('[TEATRO] ' . $e);
    responder_error_interno($e);
});

// Errores fatales que no pasan por el manejador de excepciones (p. ej. memoria agotada).
register_shutdown_function(static function (): void {
    $error = error_get_last();
    $fatales = E_ERROR | E_PARSE | E_CORE_ERROR | E_COMPILE_ERROR | E_USER_ERROR;

    if ($error !== null && ($error['type'] & $fatales) !== 0) {
        error_log(sprintf('[TEATRO] Error fatal: %s en %s:%d', $error['message'], $error['file'], $error['line']));
        responder_error_interno();
    }
});

ob_start();

require __DIR__ . '/helpers.php';
require __DIR__ . '/db.php';
require __DIR__ . '/sesion.php';
require __DIR__ . '/obras.php';
require __DIR__ . '/layout.php';

header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: same-origin');
header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; form-action 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'");
// Las páginas reflejan disponibilidad en tiempo real: no deben quedar en caché.
header('Cache-Control: no-store, max-age=0');

// URLs como /comprar.php/algo no son válidas en esta aplicación.
if (($_SERVER['PATH_INFO'] ?? '') !== '') {
    render_pagina_mensaje(404, 'Página no encontrada', 'La página que busca no existe.');
    exit;
}

iniciar_sesion();
