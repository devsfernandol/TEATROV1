-- =============================================================================
-- Respaldo de la base de datos TEATRO
-- Compatible con MySQL 5.7+ / 8.x y MariaDB 10.3+
--
-- Las fechas de los datos de prueba son relativas al momento de la
-- restauración, para que siempre existan obras futuras disponibles.
-- =============================================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS `TEATRO`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE `TEATRO`;

DROP TABLE IF EXISTS `VENTAS`;
DROP TABLE IF EXISTS `OBRA`;

-- -----------------------------------------------------------------------------
-- Tabla OBRA: funciones de teatro a la venta.
-- -----------------------------------------------------------------------------
CREATE TABLE `OBRA` (
    `cod_obra`    INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    `nombre`      VARCHAR(150)      NOT NULL,
    `fecha_obra`  DATETIME          NOT NULL COMMENT 'Fecha y hora de la función',
    `aforo`       SMALLINT UNSIGNED NOT NULL COMMENT 'Capacidad total de la sala para la función',
    `disponibles` SMALLINT UNSIGNED NOT NULL COMMENT 'Entradas que quedan por vender',
    `sala`        VARCHAR(50)       NOT NULL,
    PRIMARY KEY (`cod_obra`),
    KEY `idx_obra_fecha_disponibles` (`fecha_obra`, `disponibles`),
    CONSTRAINT `chk_obra_nombre`      CHECK (CHAR_LENGTH(TRIM(`nombre`)) > 0),
    CONSTRAINT `chk_obra_aforo`       CHECK (`aforo` > 0),
    CONSTRAINT `chk_obra_disponibles` CHECK (`disponibles` <= `aforo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Tabla VENTAS: una fila por entrada vendida.
-- numero_venta es el número de entrada que se muestra al comprador.
-- -----------------------------------------------------------------------------
CREATE TABLE `VENTAS` (
    `numero_venta` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cod_obra`     INT UNSIGNED NOT NULL,
    `comprador`    VARCHAR(20)  NOT NULL COMMENT 'Identificador (documento) del comprador',
    `fecha_compra` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`numero_venta`),
    KEY `idx_ventas_cod_obra` (`cod_obra`),
    KEY `idx_ventas_comprador` (`comprador`),
    CONSTRAINT `fk_ventas_obra`
        FOREIGN KEY (`cod_obra`) REFERENCES `OBRA` (`cod_obra`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Datos de prueba.
-- Se cumple siempre: disponibles = aforo - (ventas registradas de la obra).
-- -----------------------------------------------------------------------------
INSERT INTO `OBRA` (`cod_obra`, `nombre`, `fecha_obra`, `aforo`, `disponibles`, `sala`) VALUES
    (1, 'La casa de Bernarda Alba', TIMESTAMP(CURRENT_DATE + INTERVAL 3 DAY,  '20:00:00'), 120, 120, 'Sala Principal'),
    (2, 'Bodas de sangre',          TIMESTAMP(CURRENT_DATE + INTERVAL 7 DAY,  '19:30:00'),  80,  78, 'Sala Lorca'),
    (3, 'La vida es sueño',         TIMESTAMP(CURRENT_DATE + INTERVAL 10 DAY, '18:00:00'),   5,   2, 'Sala Calderón'),
    (4, 'Don Juan Tenorio',         TIMESTAMP(CURRENT_DATE + INTERVAL 14 DAY, '21:00:00'), 200, 200, 'Sala Principal'),
    (5, 'El sí de las niñas',       TIMESTAMP(CURRENT_DATE + INTERVAL 21 DAY, '17:00:00'),  60,  60, 'Sala Moratín'),
    -- Agotada: no debe aparecer en la cartelera.
    (6, 'Luces de bohemia',         TIMESTAMP(CURRENT_DATE + INTERVAL 5 DAY,  '20:30:00'),   3,   0, 'Sala Lorca'),
    -- Ya realizada: no debe aparecer en la cartelera.
    (7, 'Fuenteovejuna',            TIMESTAMP(CURRENT_DATE - INTERVAL 2 DAY,  '20:00:00'),  50,  48, 'Sala Principal');

INSERT INTO `VENTAS` (`numero_venta`, `cod_obra`, `comprador`, `fecha_compra`) VALUES
    ( 1, 7, 'V12345678', NOW() - INTERVAL 10 DAY),
    ( 2, 7, 'E87654321', NOW() - INTERVAL 9 DAY),
    ( 3, 2, 'V11222333', NOW() - INTERVAL 6 DAY),
    ( 4, 2, 'V44555666', NOW() - INTERVAL 5 DAY),
    ( 5, 6, 'V77888999', NOW() - INTERVAL 4 DAY),
    ( 6, 6, 'P1234567',  NOW() - INTERVAL 4 DAY),
    ( 7, 6, 'V10203040', NOW() - INTERVAL 3 DAY),
    ( 8, 3, 'V50607080', NOW() - INTERVAL 2 DAY),
    ( 9, 3, 'V90807060', NOW() - INTERVAL 1 DAY),
    (10, 3, 'E11223344', NOW() - INTERVAL 1 HOUR);
