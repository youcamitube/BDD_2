-- ============================================================
-- PROYECTO: INVENTARIO Y VENTAS
-- BASE DE DATOS: MySQL
-- DOCUMENTOS DE REFERENCIA: Doc 2 (ER), Doc 3 (Lógico), Doc 5 (Implementación)
-- ============================================================

-- ------------------------------------------------------------
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS inventario_ventas
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE inventario_ventas;

-- ------------------------------------------------------------
-- 2. TABLA: usuarios
-- Almacena los usuarios autorizados para acceder al sistema.
-- Regla de negocio: no puede existir una venta sin usuario.
-- ------------------------------------------------------------
CREATE TABLE usuarios (
    id_usuario     INT            AUTO_INCREMENT  PRIMARY KEY,
    nombre         VARCHAR(100)   NOT NULL,
    correo         VARCHAR(100)   NOT NULL        UNIQUE,
    password       VARCHAR(255)   NOT NULL,
    fecha_creacion TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- 3. TABLA: productos
-- Almacena el catálogo de productos disponibles para la venta.
-- Regla de negocio: stock nunca puede ser negativo.
--                   precio siempre debe ser mayor a cero.
-- ------------------------------------------------------------
CREATE TABLE productos (
    id_producto    INT              AUTO_INCREMENT  PRIMARY KEY,
    nombre         VARCHAR(100)     NOT NULL,
    precio         DECIMAL(10, 2)   NOT NULL,
    stock          INT              NOT NULL,
    fecha_creacion TIMESTAMP        DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precio  CHECK (precio > 0),
    CONSTRAINT chk_stock   CHECK (stock >= 0)
);

-- ------------------------------------------------------------
-- 4. TABLA: ventas
-- Almacena cada transacción de venta realizada.
-- Relación: Usuarios (1) ---< (N) Ventas
-- Regla de negocio: no puede existir una venta sin usuario.
-- ------------------------------------------------------------
CREATE TABLE ventas (
    id_venta   INT    AUTO_INCREMENT  PRIMARY KEY,
    fecha      DATE   DEFAULT (CURRENT_DATE),
    id_usuario INT    NOT NULL,
    CONSTRAINT fk_venta_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ------------------------------------------------------------
-- 5. TABLA: detalle_venta
-- Almacena los productos vendidos dentro de cada venta.
-- Relación: Ventas (1) ---< (N) Detalle_Venta
--           Productos (1) ---< (N) Detalle_Venta
-- Regla de negocio: no puede existir un detalle sin venta
--                   ni sin producto.
-- ------------------------------------------------------------
CREATE TABLE detalle_venta (
    id_detalle  INT              AUTO_INCREMENT  PRIMARY KEY,
    id_venta    INT              NOT NULL,
    id_producto INT              NOT NULL,
    cantidad    INT              NOT NULL,
    subtotal    DECIMAL(10, 2)   NOT NULL,
    CONSTRAINT fk_detalle_venta
        FOREIGN KEY (id_venta)
        REFERENCES ventas (id_venta)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto)
        REFERENCES productos (id_producto)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_cantidad  CHECK (cantidad > 0),
    CONSTRAINT chk_subtotal  CHECK (subtotal > 0)
);

-- ------------------------------------------------------------
-- 6. TABLA: movimientos_inventario
-- Audita todas las entradas y salidas del inventario.
-- Relación: Productos (1) ---< (N) Movimientos_Inventario
-- Regla de negocio: toda modificación del inventario debe
--                   generar un registro de movimiento.
-- ------------------------------------------------------------
CREATE TABLE movimientos_inventario (
    id_movimiento   INT              AUTO_INCREMENT  PRIMARY KEY,
    id_producto     INT              NOT NULL,
    tipo_movimiento VARCHAR(20)      NOT NULL,
    cantidad        INT              NOT NULL,
    fecha           TIMESTAMP        DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movimiento_producto
        FOREIGN KEY (id_producto)
        REFERENCES productos (id_producto)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_tipo_movimiento
        CHECK (tipo_movimiento IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT chk_mov_cantidad
        CHECK (cantidad > 0)
);

-- ------------------------------------------------------------
-- 7. ÍNDICES
-- Mejoran el rendimiento en búsquedas frecuentes.
-- ------------------------------------------------------------
CREATE INDEX idx_producto_nombre ON productos (nombre);
CREATE INDEX idx_venta_fecha     ON ventas    (fecha);

-- ------------------------------------------------------------
-- 8. TRIGGER: reducir stock al registrar un detalle de venta
-- Regla 6: al registrar una venta debe disminuir el inventario.
-- Regla 7: toda modificación del inventario debe generar un
--          movimiento registrado en movimientos_inventario.
-- ------------------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_after_detalle_insert
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    -- Reducir el stock del producto vendido
    UPDATE productos
    SET    stock = stock - NEW.cantidad
    WHERE  id_producto = NEW.id_producto;

    -- Registrar el movimiento de salida en el inventario
    INSERT INTO movimientos_inventario
        (id_producto, tipo_movimiento, cantidad)
    VALUES
        (NEW.id_producto, 'SALIDA', NEW.cantidad);
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 9. DATOS INICIALES
-- ------------------------------------------------------------

-- Usuarios
INSERT INTO usuarios (nombre, correo, password)
VALUES ('Administrador', 'admin@empresa.com', '123456');

-- Productos
INSERT INTO productos (nombre, precio, stock)
VALUES
    ('Mouse',      50000.00,  20),
    ('Teclado',    80000.00,  15),
    ('Monitor',   700000.00,  10),
    ('Impresora', 450000.00,   8),
    ('Laptop',   2500000.00,   5);

-- ------------------------------------------------------------
-- 10. DATOS DE PRUEBA
-- ------------------------------------------------------------

-- Registrar una venta de prueba (usuario 1)
INSERT INTO ventas (id_usuario)
VALUES (1);

-- Registrar detalle: 2 unidades de Mouse (id_producto = 1)
-- El trigger se encargará de:
--   a) Reducir el stock del Mouse de 20 a 18.
--   b) Insertar un movimiento SALIDA en movimientos_inventario.
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, subtotal)
VALUES (1, 1, 2, 100000.00);

-- ------------------------------------------------------------
-- 11. CONSULTAS DE VALIDACIÓN
-- ------------------------------------------------------------

-- Ver todas las tablas creadas
SHOW TABLES;

-- Estructura de la tabla productos
DESCRIBE productos;

-- Todos los usuarios
SELECT * FROM usuarios;

-- Todos los productos (con stock actualizado tras la venta de prueba)
SELECT * FROM productos;

-- Todas las ventas
SELECT * FROM ventas;

-- Detalle de ventas
SELECT * FROM detalle_venta;

-- Movimientos de inventario (generado automáticamente por el trigger)
SELECT * FROM movimientos_inventario;

-- Ventas con nombre de usuario
SELECT
    v.id_venta,
    v.fecha,
    u.nombre AS usuario
FROM ventas v
INNER JOIN usuarios u ON v.id_usuario = u.id_usuario;

-- Productos vendidos con nombre y cantidades
SELECT
    d.id_detalle,
    p.nombre        AS producto,
    d.cantidad,
    d.subtotal
FROM detalle_venta d
INNER JOIN productos p ON d.id_producto = p.id_producto;

-- Reporte de ventas agrupado por producto
SELECT
    p.nombre          AS producto,
    SUM(d.cantidad)   AS total_unidades,
    SUM(d.subtotal)   AS total_ingresos
FROM detalle_venta d
INNER JOIN productos p ON d.id_producto = p.id_producto
GROUP BY p.id_producto, p.nombre
ORDER BY total_ingresos DESC;

-- ------------------------------------------------------------
-- 12. PRUEBA DE RESTRICCIONES (se espera error en cada caso)
-- ------------------------------------------------------------

-- Precio negativo → debe generar error de restricción CHECK
-- INSERT INTO productos (nombre, precio, stock)
-- VALUES ('Producto Error', -1000, 5);

-- Stock negativo → debe generar error de restricción CHECK
-- INSERT INTO productos (nombre, precio, stock)
-- VALUES ('Producto Error', 5000, -1);

-- Tipo de movimiento inválido → debe generar error CHECK
-- INSERT INTO movimientos_inventario (id_producto, tipo_movimiento, cantidad)
-- VALUES (1, 'DEVOLUCION', 5);

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
