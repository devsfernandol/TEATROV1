<?php

declare(strict_types=1);

/**
 * Tareas de base de datos de ./instalar.sh para un MySQL que ya existe.
 *
 * Se ejecuta en un contenedor de la imagen teatro-php, con el mismo controlador
 * (pdo_mysql) que usa la aplicación: si el instalador conecta, la aplicación también.
 *
 * Uso: php instalar-bd.php ACCIÓN
 *   probar          conecta y muestra la versión del servidor
 *   tablas          cuántas de las tablas OBRA y VENTAS existen ya en TEATRO (0, 1 o 2)
 *   importar        restaura /teatro.sql (crea TEATRO; reemplaza OBRA y VENTAS)
 *   crear-usuario   crea o actualiza APP_USER@APP_HOST con permisos mínimos sobre TEATRO
 *   verificar       con las credenciales de BD_*, lee OBRA y VENTAS de TEATRO
 *
 * Conexión: BD_SOCKET, o BD_HOST y BD_PORT; BD_USER y BD_PASSWORD.
 * No es accesible desde el navegador: Nginx solo publica las páginas de la aplicación.
 */

function conectar(?string $base = null): PDO
{
    $socket = getenv('BD_SOCKET') ?: '';
    $servidor = $socket !== ''
        ? 'unix_socket=' . $socket
        : sprintf('host=%s;port=%d', getenv('BD_HOST') ?: '127.0.0.1', (int) (getenv('BD_PORT') ?: 3306));

    return new PDO(
        sprintf('mysql:%s;charset=utf8mb4%s', $servidor, $base !== null ? ';dbname=' . $base : ''),
        getenv('BD_USER') ?: 'root',
        getenv('BD_PASSWORD') ?: '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 10]
    );
}

try {
    switch ($argv[1] ?? '') {
        case 'probar':
            echo conectar()->query('SELECT VERSION()')->fetchColumn(), "\n";
            break;

        case 'tablas':
            echo conectar()->query(
                "SELECT COUNT(*) FROM information_schema.TABLES
                  WHERE TABLE_SCHEMA = 'TEATRO' AND TABLE_NAME IN ('OBRA', 'VENTAS')"
            )->fetchColumn(), "\n";
            break;

        case 'importar':
            // El respaldo tiene varias sentencias: se ejecutan juntas y se recorre
            // cada resultado para que un error en cualquiera de ellas se detecte.
            $pdo = conectar();
            $pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, true);
            $resultado = $pdo->query((string) file_get_contents('/teatro.sql'));
            while ($resultado->nextRowset()) {
            }
            echo "ok\n";
            break;

        case 'crear-usuario':
            $pdo = conectar();
            $cuenta = $pdo->quote((string) getenv('APP_USER')) . '@' . $pdo->quote((string) getenv('APP_HOST'));
            $clave = $pdo->quote((string) getenv('APP_PASSWORD'));
            // ALTER USER deja la clave nueva aunque el usuario ya existiera de una instalación anterior.
            $pdo->exec("CREATE USER IF NOT EXISTS $cuenta IDENTIFIED BY $clave");
            $pdo->exec("ALTER USER $cuenta IDENTIFIED BY $clave");
            $pdo->exec("GRANT SELECT, INSERT, UPDATE, DELETE ON `TEATRO`.* TO $cuenta");
            echo "ok\n";
            break;

        case 'verificar':
            $pdo = conectar('TEATRO');
            $obras = $pdo->query('SELECT COUNT(*) FROM OBRA')->fetchColumn();
            $ventas = $pdo->query('SELECT COUNT(*) FROM VENTAS')->fetchColumn();
            echo "$obras obras, $ventas ventas\n";
            break;

        default:
            fwrite(STDERR, "Acción desconocida\n");
            exit(2);
    }
} catch (PDOException $e) {
    // Solo el mensaje de MySQL (por ejemplo, "Access denied for user..."), sin rutas ni trazas.
    fwrite(STDERR, preg_replace('/^SQLSTATE\[[^\]]*\]\s*(\[\d+\]\s*)?/', '', $e->getMessage()) . "\n");
    exit(1);
}
