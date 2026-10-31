<?php

declare(strict_types=1);

/**
 * Límite de intentos por dirección IP en una ventana de tiempo.
 *
 * La cuenta se guarda en archivos (uno por acción e IP) para funcionar en
 * cualquier servidor sin extensiones adicionales. Cada archivo se bloquea con
 * flock mientras se lee y actualiza, así que varias peticiones simultáneas de
 * la misma IP no pueden saltarse el límite.
 *
 * Detrás de un proxy inverso, REMOTE_ADDR debe ser la IP real del visitante
 * (en Docker lo resuelve Nginx; en Apache, mod_remoteip). Ver LEAME.
 */

/**
 * Registra un intento de la acción para la IP actual si todavía no alcanzó el
 * máximo de la ventana. Devuelve false si lo alcanzó.
 *
 * Si la cuenta no se puede guardar (carpeta sin permisos), el intento se
 * permite y el problema queda en el log: un fallo de esta protección no debe
 * impedir que los clientes compren.
 */
function consumir_intento(string $accion, int $maximo, int $ventanaSegundos): bool
{
    if ($maximo <= 0) {
        return true;
    }

    $directorio = config()['limites']['directorio'];
    $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
    $archivo = $directorio . '/' . hash('sha256', $accion . '|' . $ip);

    try {
        // Con @ porque otra petición simultánea puede haberla creado un instante antes.
        if (!is_dir($directorio) && !@mkdir($directorio, 0700, true) && !is_dir($directorio)) {
            throw new RuntimeException("No se pudo crear $directorio");
        }

        $manejador = fopen($archivo, 'c+');
        if ($manejador === false) {
            throw new RuntimeException("No se pudo abrir $archivo");
        }

        try {
            flock($manejador, LOCK_EX);

            $ahora = time();
            $intentos = array_values(array_filter(
                array_map('intval', explode(',', (string) stream_get_contents($manejador))),
                static function (int $momento) use ($ahora, $ventanaSegundos): bool {
                    return $momento > $ahora - $ventanaSegundos;
                }
            ));

            $permitido = count($intentos) < $maximo;
            if ($permitido) {
                $intentos[] = $ahora;
            }

            ftruncate($manejador, 0);
            rewind($manejador);
            fwrite($manejador, implode(',', $intentos));

            return $permitido;
        } finally {
            // Cerrar el archivo libera el bloqueo.
            fclose($manejador);
        }
    } catch (Throwable $e) {
        error_log('[TEATRO-AVISO] No se pudo aplicar el límite de intentos: ' . $e->getMessage());

        return true;
    }
}
