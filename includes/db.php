<?php

declare(strict_types=1);

/**
 * Devuelve la conexión PDO compartida, creándola en el primer uso.
 */
function db(): PDO
{
    static $pdo = null;

    if ($pdo === null) {
        $cfg = config()['db'];
        $servidor = ($cfg['socket'] ?? '') !== ''
            ? sprintf('unix_socket=%s', $cfg['socket'])
            : sprintf('host=%s;port=%d', $cfg['host'], $cfg['port']);
        $dsn = sprintf('mysql:%s;dbname=%s;charset=utf8mb4', $servidor, $cfg['name']);

        $pdo = new PDO($dsn, $cfg['user'], $cfg['password'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }

    return $pdo;
}
