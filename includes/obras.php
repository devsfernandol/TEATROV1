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
 * @return int Número de venta (número de entrada) generado.
 *
 * @throws ObraNoDisponibleException Si la obra no existe, está agotada o ya pasó.
 */
function registrar_venta(PDO $pdo, int $codObra, string $comprador): int
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
