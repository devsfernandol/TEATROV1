<?php

declare(strict_types=1);

/**
 * Acceso a datos de obras y ventas.
 *
 * Regla de negocio: una obra está disponible si le quedan entradas y su fecha
 * es posterior al momento actual. La hora actual la decide siempre MySQL
 * (NOW()), para no depender de la zona horaria configurada en PHP.
 */

final class ObraNoDisponibleException extends RuntimeException
{
}

final class LimiteEntradasException extends RuntimeException
{
}

/**
 * Asegura los tipos de una fila de OBRA. Según la versión de PHP y el modo de
 * consulta, MySQL puede devolver los números como texto.
 */
function tipar_obra(array $fila): array
{
    $fila['cod_obra'] = (int) $fila['cod_obra'];
    $fila['aforo'] = (int) $fila['aforo'];
    $fila['disponibles'] = (int) $fila['disponibles'];

    return $fila;
}

/**
 * @return list<array{cod_obra: int, nombre: string, fecha_obra: string, aforo: int, disponibles: int, sala: string}>
 */
function obtener_obras_disponibles(PDO $pdo): array
{
    $sql = 'SELECT cod_obra, nombre, fecha_obra, aforo, disponibles, sala
              FROM OBRA
             WHERE disponibles > 0
               AND fecha_obra > NOW()
          ORDER BY fecha_obra ASC, nombre ASC';

    return array_map('tipar_obra', $pdo->query($sql)->fetchAll());
}

/**
 * @return array{cod_obra: int, nombre: string, fecha_obra: string, aforo: int, disponibles: int, sala: string}|null
 */
function obtener_obra_disponible(PDO $pdo, int $codObra): ?array
{
    $stmt = $pdo->prepare(
        'SELECT cod_obra, nombre, fecha_obra, aforo, disponibles, sala
           FROM OBRA
          WHERE cod_obra = :cod_obra
            AND disponibles > 0
            AND fecha_obra > NOW()'
    );
    $stmt->execute(['cod_obra' => $codObra]);

    $obra = $stmt->fetch();

    return $obra === false ? null : tipar_obra($obra);
}

/**
 * Registra la venta de una entrada y descuenta una de las disponibles.
 *
 * El descuento es un UPDATE condicional y atómico: si dos compradores piden la
 * última entrada al mismo tiempo, InnoDB serializa ambas actualizaciones sobre
 * la fila y solo una de ellas encuentra disponibles > 0. Así nunca se vende
 * por encima del aforo.
 *
 * El límite de entradas por comprador se comprueba después de ese UPDATE,
 * mientras la transacción retiene la fila de la obra: las compras simultáneas
 * de una misma obra se atienden de a una, así que el mismo identificador no
 * puede superar el límite comprando desde varios navegadores a la vez.
 *
 * Si MySQL aborta la transacción por un bloqueo (deadlock o tiempo de espera
 * agotado bajo alta concurrencia), la compra se reintenta automáticamente:
 * la transacción completa se deshizo, así que reintentar es seguro.
 *
 * @return int Número de venta (número de entrada) generado.
 *
 * @param int $maximoPorComprador Entradas que un comprador puede tener para la obra (0 = sin límite).
 *
 * @throws ObraNoDisponibleException Si la obra no existe, está agotada o ya pasó.
 * @throws LimiteEntradasException Si el comprador ya tiene el máximo de entradas de la obra.
 */
function registrar_venta(PDO $pdo, int $codObra, string $comprador, int $maximoPorComprador): int
{
    $intentosMaximos = 3;

    for ($intento = 1; ; $intento++) {
        try {
            return registrar_venta_en_transaccion($pdo, $codObra, $comprador, $maximoPorComprador);
        } catch (PDOException $e) {
            if ($intento >= $intentosMaximos || !es_error_de_bloqueo($e)) {
                throw $e;
            }
            error_log(sprintf('[TEATRO-AVISO] Reintento %d de la compra por bloqueo: %s', $intento, $e->getMessage()));
            usleep(50000 * $intento);
        }
    }
}

/**
 * Indica si la excepción corresponde a un deadlock (1213) o a un tiempo de
 * espera de bloqueo agotado (1205) de MySQL.
 */
function es_error_de_bloqueo(PDOException $e): bool
{
    $codigoMysql = (int) ($e->errorInfo[1] ?? 0);

    return in_array($codigoMysql, [1205, 1213], true);
}

function registrar_venta_en_transaccion(PDO $pdo, int $codObra, string $comprador, int $maximoPorComprador): int
{
    $pdo->beginTransaction();

    try {
        $descontar = $pdo->prepare(
            'UPDATE OBRA
                SET disponibles = disponibles - 1
              WHERE cod_obra = :cod_obra
                AND disponibles > 0
                AND fecha_obra > NOW()'
        );
        $descontar->execute(['cod_obra' => $codObra]);

        if ($descontar->rowCount() !== 1) {
            throw new ObraNoDisponibleException('La obra no está disponible para la venta.');
        }

        if ($maximoPorComprador > 0) {
            $compradas = $pdo->prepare(
                'SELECT COUNT(*)
                   FROM VENTAS
                  WHERE cod_obra = :cod_obra
                    AND comprador = :comprador
                    FOR UPDATE'
            );
            $compradas->execute(['cod_obra' => $codObra, 'comprador' => $comprador]);

            if ((int) $compradas->fetchColumn() >= $maximoPorComprador) {
                throw new LimiteEntradasException('El comprador ya tiene el máximo de entradas de la obra.');
            }
        }

        $insertar = $pdo->prepare(
            'INSERT INTO VENTAS (cod_obra, comprador, fecha_compra)
             VALUES (:cod_obra, :comprador, NOW())'
        );
        $insertar->execute([
            'cod_obra'  => $codObra,
            'comprador' => $comprador,
        ]);

        $numeroVenta = (int) $pdo->lastInsertId();

        $pdo->commit();

        return $numeroVenta;
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
}

/**
 * @return array{numero_venta: int, comprador: string, fecha_compra: string, cod_obra: int, nombre: string, fecha_obra: string, sala: string}|null
 */
function obtener_venta(PDO $pdo, int $numeroVenta): ?array
{
    $stmt = $pdo->prepare(
        'SELECT v.numero_venta, v.comprador, v.fecha_compra,
                o.cod_obra, o.nombre, o.fecha_obra, o.sala
           FROM VENTAS v
           JOIN OBRA o ON o.cod_obra = v.cod_obra
          WHERE v.numero_venta = :numero_venta'
    );
    $stmt->execute(['numero_venta' => $numeroVenta]);

    $venta = $stmt->fetch();
    if ($venta === false) {
        return null;
    }

    $venta['numero_venta'] = (int) $venta['numero_venta'];
    $venta['cod_obra'] = (int) $venta['cod_obra'];

    return $venta;
}
