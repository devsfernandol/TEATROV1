<?php

declare(strict_types=1);

/**
 * Manejo de la sesión del comprador.
 *
 * Cada formulario de compra lleva un token de un solo uso ligado a la obra.
 * El token cumple dos funciones:
 *   - Protección CSRF: solo se aceptan compras con un token emitido por esta sesión.
 *   - Idempotencia: si el mismo formulario se envía dos veces (doble clic,
 *     reenvío del navegador), la segunda petición no genera otra venta, sino
 *     que lleva a la confirmación de la venta ya registrada.
 */

const MAX_TOKENS_COMPRA = 20;
const MAX_VENTAS_SESION = 50;

function iniciar_sesion(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }

    ini_set('session.use_strict_mode', '1');
    ini_set('session.use_only_cookies', '1');

    session_name('TEATRO_SESION');
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'secure'   => es_https(),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);

    session_start();
}

/**
 * Indica si el visitante llegó por HTTPS, también cuando hay un proxy inverso
 * o un balanceador delante que atiende el HTTPS y reenvía la petición por HTTP.
 *
 * Confiar en X-Forwarded-Proto es seguro aquí: solo decide si la cookie de
 * sesión se marca Secure. Quien envíe el encabezado falso solo consigue que
 * su propio navegador no devuelva la cookie por HTTP.
 */
function es_https(): bool
{
    if ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (int) ($_SERVER['SERVER_PORT'] ?? 0) === 443) {
        return true;
    }

    // X-Forwarded-Proto puede traer una lista si hay varios proxies: vale el primero (el del visitante).
    $protocolo = strtolower(trim(explode(',', (string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''))[0]));

    return $protocolo === 'https'
        || preg_match('/(^|[;,\s])proto=https($|[;,\s])/i', (string) ($_SERVER['HTTP_FORWARDED'] ?? '')) === 1;
}

/**
 * Emite un token nuevo para comprar una entrada de la obra indicada.
 */
function emitir_token_compra(int $codObra): string
{
    $token = bin2hex(random_bytes(32));

    $tokens = $_SESSION['tokens_compra'] ?? [];
    $tokens[$token] = ['cod_obra' => $codObra, 'numero_venta' => null];

    // Se conservan solo los más recientes para acotar el tamaño de la sesión.
    $_SESSION['tokens_compra'] = array_slice($tokens, -MAX_TOKENS_COMPRA, null, true);

    return $token;
}

/**
 * Devuelve los datos asociados a un token emitido por esta sesión,
 * o null si el token no existe o no es válido.
 *
 * @param mixed $token
 *
 * @return array{cod_obra: int, numero_venta: int|null}|null
 */
function obtener_token_compra($token): ?array
{
    if (!is_string($token) || preg_match('/^[a-f0-9]{64}$/', $token) !== 1) {
        return null;
    }

    return $_SESSION['tokens_compra'][$token] ?? null;
}

/**
 * Marca el token como usado y registra la venta como propia de esta sesión.
 */
function consumir_token_compra(string $token, int $numeroVenta): void
{
    $_SESSION['tokens_compra'][$token]['numero_venta'] = $numeroVenta;

    recordar_venta_en_sesion($numeroVenta);
}

/**
 * Permite ver la venta desde esta sesión (después de comprarla o de
 * recuperarla con su número y el identificador del comprador).
 */
function recordar_venta_en_sesion(int $numeroVenta): void
{
    $ventas = $_SESSION['ventas'] ?? [];
    if (!in_array($numeroVenta, $ventas, true)) {
        $ventas[] = $numeroVenta;
    }
    $_SESSION['ventas'] = array_slice($ventas, -MAX_VENTAS_SESION);
}

/**
 * Indica si la venta fue realizada en esta sesión. Evita que un usuario
 * consulte las entradas de otros cambiando el número en la URL.
 */
function venta_pertenece_a_sesion(int $numeroVenta): bool
{
    return in_array($numeroVenta, $_SESSION['ventas'] ?? [], true);
}

/**
 * Indica si el navegador envió la cookie de sesión. Si no la envía, el
 * navegador tiene las cookies desactivadas y no es posible completar la compra.
 */
function navegador_envio_cookie_de_sesion(): bool
{
    return isset($_COOKIE[session_name()]);
}
