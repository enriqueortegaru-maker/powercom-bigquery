BEGIN



-- DECLARACIÓN DE VARIABLES
DECLARE mes_string STRING;
DECLARE fecha_inicio DATE;
DECLARE fecha_fin DATE;
DECLARE mes_anterior STRING;

SET mes_string = CAST(mes_int AS STRING);
SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
SET fecha_fin = LAST_DAY(fecha_inicio);
SET mes_anterior = FORMAT_DATE('%Y%m', DATE_SUB(fecha_inicio, INTERVAL 1 MONTH));


-- call `mm-commissions-reporting.COMISIONES.pr_cartera_dorus_jsm`(202609, ['JSM'])


-- BASICAMENTE MI CARTERA VA A DEPENDER DE 2 PATAS:

    -- 1) LO QUE SE PAGO EL MES PASADO Y NO SE HA DADO DE BAJA, NOS APOYAMOS EN EL BUCKET ESTE PRIMER MES, POSTERIORMENTE DE NUESTRO PROPIO CÁLCULO.
    -- 2) LA CARTERA DERIVADA DE LAS ALTAS NUEVAS DEL MES DE LIQUIDACION

    -- AHORA BIEN, TENEMOS QUE TENER CUIDADO EN EL PRIMER PUNTO CON LOS CAMBIOS DE TARIFA, TITULAR, ETC. TENEMOS QUE PAGAR LA CARTERA A QUIÉN CORRESPONDA


-- ==========================================
-- PASO 1: CREACIÓN DE LA BASE DE CARTERA
-- ==========================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_cartera_JSM` AS
WITH facturacion_mes AS (
    SELECT * 
    FROM `mm-dwh-prod.00_SANDBOX_DORUS.facturacion`
    WHERE fecha_factura BETWEEN fecha_inicio AND fecha_fin
      AND tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX', 'MOVIL', 'OTROS')
),

mes_anterior AS (
    SELECT 
        id_contrato AS contrato,
        CAST(id_cliente AS INT64) AS codigo_cli,
        entidad AS empresa_distribuidora,
        cif_entidad AS cif,
        DATE(SAFE_CAST(fecha_instalacion AS TIMESTAMP)) AS fecha_activacion,
        DATE(SAFE_CAST(fecha_baja AS TIMESTAMP)) AS fecha_baja,
        CAST(codigo_pas AS INT64) AS codigo_pas,
        CAST(codigo_pas_anterior AS INT64) AS codigo_pas_anterior,
        nombre_producto AS producto,
        sfid,
        tipo_cambio AS estado,
        servicio AS tipo_servicio,
        CAST(REPLACE(IMPORTE_COMISION, ',', '.') AS FLOAT64) AS comision
    FROM `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`
    WHERE tipo_comision = 'GESTIÓN CLIENTES'
      AND data_month_id = mes_anterior
      AND CAST(codigo_pas AS INT64) NOT IN (
          SELECT DISTINCT codigo_pas
          FROM `mm-dwh-prod.00_SANDBOX_DORUS.seguimientoventas`
          WHERE fecha_baja BETWEEN fecha_inicio AND fecha_fin
            AND estado IN ('BAJA', 'BAJAS CAMBIO DE TECNOLOGIA')
      )
),

mes_curso AS (
    SELECT 
        contrato,
        codigo_cli,
        empresa_distribuidora,
        cif,
        fecha_activacion,
        fecha_baja,
        codigo_pas,
        codigo_pas_anterior_ct AS codigo_pas_anterior,
        producto,
        sfid,
        estado,
        tipo_servicio,
        CAST(NULL AS FLOAT64) AS comision
    FROM `mm-commissions-reporting.TEMP.comisiones_upfront_JSM`
    WHERE fecha_baja IS NULL
)

SELECT * FROM mes_anterior
UNION ALL
SELECT * FROM mes_curso;


-- ==========================================
-- PASO 2: CÁLCULO DE COMISIONES - FIBRA / FIJO / WIMAX
-- ==========================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.facturacion_fibra_JSM` AS
WITH facturacion_mes AS (
    SELECT * 
    FROM `mm-dwh-prod.00_SANDBOX_DORUS.facturacion`
    WHERE fecha_factura BETWEEN fecha_inicio AND fecha_fin
      AND tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX')
),

intervalo_eops AS (
    SELECT 
        a.sfid,
        a.tipo_servicio,
        COUNT(DISTINCT a.codigo_pas) AS eop
    FROM facturacion_mes a
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b ON a.sfid = b.id_comisionista
    WHERE a.tipo_servicio IN ('FIBRA', 'WIMAX')
      AND b.canal = 'MREXTv2'
    GROUP BY a.sfid, a.tipo_servicio
),

eops_DCOOP AS (
    SELECT 
        b.cif_padre,
        b.distribuidor_padre,
        a.tipo_reporte,
        COUNT(DISTINCT a.codigo_pas) AS eop
    FROM facturacion_mes a
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b 
        ON b.cif_padre = 'F29249018' AND a.sfid = b.sfid_hijo
    WHERE a.tipo_servicio IN ('FIBRA', 'WIMAX')
    GROUP BY b.cif_padre, b.distribuidor_padre, a.tipo_reporte
),

base_no_movil AS (
    SELECT 
        a.id, a.codigo_pas, a.codigo_cli, a.cliente, a.dni, a.tipo_servicio, a.tipo_reporte, a.concepto,
        CASE WHEN a.tipo_servicio = 'FIBRA' AND b.eop < 1500 THEN 1 ELSE 1500 END AS producto_eop_fibra_v1,
        CAST(NULL AS INT64) AS producto_eop_fibra_v2,
        CASE WHEN a.tipo_servicio = 'WIMAX' AND b.eop < 1500 THEN 1 ELSE 1500 END AS producto_eop_wimax,
        a.descripcion, a.sfid, a.operadora, a.fecha_emision, 
        a.fecha_inicio_facturacion_servicio, a.fecha_fin_facturacion_servicio, a.importe_sin_iva
    FROM facturacion_mes a
    INNER JOIN intervalo_eops b ON a.sfid = b.sfid
    WHERE a.tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX')
),

base_no_movil_dcoop AS (
    SELECT 
        a.id, a.codigo_pas, a.codigo_cli, a.cliente, a.dni, a.tipo_servicio, a.tipo_reporte, a.concepto,
        CASE 
            WHEN a.tipo_reporte = 'FIBRA BLANCA' AND b.eop < 850 THEN 1
            WHEN a.tipo_reporte = 'FIBRA BLANCA' AND b.eop >= 850 THEN 850
            ELSE NULL 
        END AS producto_eop_fibra_v1,
        CASE 
            WHEN a.tipo_reporte = 'FIBRA PROPIA' AND b.eop < 500 THEN 1
            WHEN a.tipo_reporte = 'FIBRA PROPIA' AND b.eop >= 500 AND b.eop < 850 THEN 501
            WHEN a.tipo_reporte = 'FIBRA PROPIA' AND b.eop >= 850 THEN 850
        END AS producto_eop_fibra_v2,
        CASE 
            WHEN a.tipo_reporte = 'WIMAX' AND b.eop < 500 THEN 1
            WHEN a.tipo_reporte = 'WIMAX' AND b.eop >= 500 AND b.eop < 850 THEN 501
            WHEN a.tipo_reporte = 'WIMAX' AND b.eop >= 850 THEN 850
        END AS producto_eop_wimax,
        a.descripcion, a.sfid, a.operadora, a.fecha_emision, 
        a.fecha_inicio_facturacion_servicio, a.fecha_fin_facturacion_servicio, a.importe_sin_iva
    FROM facturacion_mes a
    INNER JOIN eops_DCOOP b ON a.tipo_reporte = b.tipo_reporte
    WHERE a.tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX')
),

calculo_comision AS (
    SELECT 
        f.*,
        b.id_comisionista,
        b.documento AS cif,
        c.marco_retributivo,
        c.gestion,
        c.gestion * f.importe_sin_iva AS comision
    FROM base_no_movil f
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b ON f.sfid = b.id_comisionista
    INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_CARTERA_JSM` c 
        ON b.canal = c.marco_retributivo 
        AND c.gestion <> 0
        AND (
            (f.tipo_reporte IN ('FIBRA BLANCA', 'FIBRA PROPIA') AND b.canal = 'MREXTv2' AND f.producto_eop_fibra_v1 = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'WIMAX' AND b.canal = 'MREXTv2' AND f.producto_eop_wimax = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte IN ('FIBRA BLANCA', 'FIBRA PROPIA', 'WIMAX', 'FIJO') AND b.canal <> 'MREXTv2' AND f.tipo_reporte = c.servicio)
        )
    WHERE c.marco_retributivo IS NOT NULL

    UNION ALL

    SELECT 
        f.*,
        b.sfid_hijo AS id_comisionista,
        b.cif_padre AS cif,
        c.marco_retributivo,
        c.gestion,
        c.gestion * f.importe_sin_iva AS comision
    FROM base_no_movil_dcoop f
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b ON f.sfid = b.sfid_hijo
    INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_CARTERA_JSM` c 
        ON b.MARCO_RETRIBUTIVO_PADRE = c.marco_retributivo 
        AND c.gestion <> 0
        AND (
            (f.tipo_reporte = 'FIBRA BLANCA' AND b.marco_retributivo_padre = 'DCOOP' AND f.producto_eop_fibra_v1 = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'FIBRA PROPIA' AND b.marco_retributivo_padre = 'DCOOP' AND f.producto_eop_fibra_v2 = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'WIMAX' AND b.marco_retributivo_padre = 'DCOOP' AND f.producto_eop_wimax = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte IN ('FIBRA BLANCA', 'FIBRA PROPIA', 'WIMAX', 'FIJO') AND b.marco_retributivo_padre = 'COOP-PANDERA' AND f.tipo_reporte = c.servicio)
        )
    WHERE c.marco_retributivo IS NOT NULL
)

SELECT codigo_pas, sfid, SUM(comision) AS comision
FROM calculo_comision
GROUP BY codigo_pas, sfid;


-- ==========================================
-- PASO 3: CÁLCULO DE COMISIONES - MÓVIL
-- ==========================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.facturacion_movil_JSM` AS
WITH facturacion_mes AS (
    SELECT * 
    FROM `mm-dwh-prod.00_SANDBOX_DORUS.facturacion`
    WHERE fecha_factura BETWEEN fecha_inicio AND fecha_fin
      AND tipo_servicio IN ('MOVIL', 'OTROS')
),

intervalo_eops AS (
    SELECT 
        a.sfid,
        a.tipo_servicio,
        COUNT(DISTINCT a.codigo_pas) AS eop
    FROM facturacion_mes a
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b ON a.sfid = b.id_comisionista
    WHERE a.tipo_servicio = 'MOVIL'
      AND b.canal IN ('MREXTv2', 'NMDR')
    GROUP BY a.sfid, a.tipo_servicio
),

eops_DCOOP AS (
    SELECT 
        b.cif_padre,
        b.distribuidor_padre,
        a.tipo_reporte,
        COUNT(DISTINCT a.codigo_pas) AS eop
    FROM facturacion_mes a
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b 
        ON b.cif_padre = 'F29249018' AND a.sfid = b.sfid_hijo
    WHERE a.tipo_servicio = 'MOVIL'
    GROUP BY b.cif_padre, b.distribuidor_padre, a.tipo_reporte
),

base_movil AS (
    SELECT 
        a.id, 
        a.codigo_pas, 
        a.codigo_cli, 
        a.cliente, 
        a.dni, 
        a.tipo_servicio, 
        a.tipo_reporte, 
        a.concepto,
        CASE 
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop < 1500 THEN 1 
            ELSE 1500 
        END AS producto_eop_movil_v1,
        CASE 
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop < 3000 THEN 1
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop >= 3000 AND b.eop < 10000 THEN 3001
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop >= 10000 THEN 10001
        END AS producto_eop_movil_v2,
        CASE 
            WHEN a.concepto like 'BONO%' or a.concepto like 'BONO%' THEN 'SERVICIOS ADICIONALES (BONOS DE MINUTOS, DATOS, ETC.)' 
            ELSE null
        END as producto_otros_mresp,
        CASE 
            WHEN a.concepto like 'BONO%' or a.concepto like 'BONO%' THEN 'SERVICIOS ADICIONALES (BONOS DE MINUTOS, DATOS, ETC.)' 
            ELSE null
        END as producto_otros_mrin,

        a.descripcion, a.sfid, a.operadora, a.fecha_emision, 
        a.fecha_inicio_facturacion_servicio, a.fecha_fin_facturacion_servicio, a.importe_sin_iva
    FROM facturacion_mes a
    LEFT JOIN intervalo_eops b ON a.sfid = b.sfid
    WHERE a.tipo_servicio = 'MOVIL'
),

base_movil_dcoop AS (
    SELECT 
        a.id, a.codigo_pas, a.codigo_cli, a.cliente, a.dni, a.tipo_servicio, a.tipo_reporte, a.concepto,
        0 AS producto_eop_movil_v1,
        CASE 
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop < 3500 THEN 1
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop >= 3500 AND b.eop < 5000 THEN 3501
            WHEN a.tipo_servicio = 'MOVIL' AND b.eop >= 5000 THEN 5000
        END AS producto_eop_movil_v2,
        '0' AS producto_otros_mresp,
        '0' AS producto_otros_mrin,
        a.descripcion, a.sfid, a.operadora, a.fecha_emision, 
        a.fecha_inicio_facturacion_servicio, a.fecha_fin_facturacion_servicio, a.importe_sin_iva
    FROM facturacion_mes a
    INNER JOIN eops_DCOOP b ON a.tipo_reporte = b.tipo_reporte
    WHERE a.tipo_servicio = 'MOVIL'
),

calculo_comision AS (
    SELECT 
        f.*,
        b.id_comisionista,
        b.documento AS cif,
        c.marco_retributivo,
        c.gestion,
        c.gestion * f.importe_sin_iva AS comision
    FROM base_movil f
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b ON f.sfid = b.id_comisionista
    INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_CARTERA_JSM` c 
        ON b.canal = c.marco_retributivo 
        AND c.gestion <> 0
        AND (
            (f.tipo_reporte = 'MOVIL' AND b.canal = 'MREXTv2' AND f.producto_eop_movil_v1 = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'MOVIL' AND b.canal = 'NMDR' AND f.producto_eop_movil_v2 = c.desde_eop AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'MOVIL' AND b.canal NOT IN ('MREXTv2', 'NMDR') AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'OTROS' AND b.canal = 'MRESP' AND f.producto_otros_mresp = c.producto AND f.tipo_reporte = c.servicio)
            OR (f.tipo_reporte = 'OTROS' AND b.canal = 'MRIN' AND f.producto_otros_mrin = c.producto AND f.tipo_reporte = c.servicio)
        )
    WHERE c.marco_retributivo IS NOT NULL

    UNION ALL

    SELECT 
        f.*,
        b.sfid_hijo AS id_comisionista,
        b.cif_padre AS cif,
        c.marco_retributivo,
        c.gestion,
        c.gestion * f.importe_sin_iva AS comision
    FROM base_movil_dcoop f
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b ON f.sfid = b.sfid_hijo
    INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_CARTERA_JSM` c 
        ON b.marco_retributivo_padre = c.marco_retributivo 
        AND c.gestion <> 0
        AND f.tipo_reporte = 'MOVIL' 
        AND b.marco_retributivo_padre = 'DCOOP'
        AND f.producto_eop_movil_v2 = c.desde_eop 
        AND f.tipo_reporte = c.servicio
    WHERE c.marco_retributivo IS NOT NULL
)

SELECT codigo_pas, sfid, SUM(comision) AS comision
FROM calculo_comision
GROUP BY codigo_pas, sfid;


-- ==========================================
-- PASO 4: TABLA FINAL DE COMISIÓN DE CARTERA (Cruzando Fibra + Móvil + Lyntia)
-- ==========================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comision_cartera_JSM` AS
WITH facturacion_mes AS (
    SELECT * 
    FROM `mm-dwh-prod.00_SANDBOX_DORUS.facturacion`
    WHERE fecha_factura BETWEEN fecha_inicio AND fecha_fin
      AND tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX', 'MOVIL')
)
-- 4.1 Cartera general uniendo comisiones de Fibra y Móvil calculadas
SELECT 
    a.*,
    COALESCE(b.comision, c.comision, a.comision) AS comision_calculada
FROM `mm-commissions-reporting.TEMP.base_cartera_JSM` a
LEFT JOIN `mm-commissions-reporting.TEMP.facturacion_fibra_JSM` b
    ON a.codigo_pas = b.codigo_pas AND a.sfid = b.sfid 
LEFT JOIN `mm-commissions-reporting.TEMP.facturacion_movil_JSM` c
    ON a.codigo_pas = c.codigo_pas AND a.sfid = c.sfid 

UNION ALL 

-- 4.2 Lyntia (Parte 1)
SELECT 
    '0' AS contrato,
    codigo_cli,
    b.razon_social AS empresa_distribuidora, 
    b.documento AS cif,
    fecha_inicio_facturacion_servicio AS fecha_activacion,
    fecha_fin_facturacion_servicio AS fecha_baja,
    codigo_pas,
    NULL AS codigo_pas_anterior,
    concepto AS producto,
    sfid,
    CAST(NULL AS STRING) AS estado,
    tipo_servicio,
    0 AS comision,
    5.94 AS comision_calculada
FROM facturacion_mes a
INNER JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b ON a.sfid = b.id_comisionista
WHERE a.sfid = 'AC128108'
  AND a.importe_sin_iva > 0

UNION ALL 

-- 4.3 Lyntia (Parte 2 con Importe Fijo)
SELECT * FROM (
    SELECT 
        '0' AS contrato,
        NULL AS codigo_cli,
        razon_social AS empresa_distribuidora, 
        documento AS cif,
        CAST(NULL AS DATE) AS fecha_activacion,
        CAST(NULL AS DATE) AS fecha_baja,
        NULL AS codigo_pas,
        NULL AS codigo_pas_anterior,
        'IMPORTE FIJO' AS producto,
        id_comisionista AS sfid,
        CAST(NULL AS STRING) AS estado,
        'OTROS' AS tipo_servicio,
        0 AS comision,
        CASE 
            WHEN id_comisionista = 'AC128108' THEN 150
            WHEN id_comisionista IN ('BV123300', 'BV123338') THEN 103
            WHEN id_comisionista IN ('BV123320', 'BV123330', 'BV223320') THEN 100
        END AS comision_calculada
    FROM `mm-commissions-reporting.GS.DEALERS_JSM` 
   
     

);

UPDATE `mm-commissions-reporting.TEMP.comision_cartera_JSM`
SET tipo_servicio = 'MOVIL'
WHERE tipo_servicio = 'MÓVIL';


DELETE `mm-commissions-reporting.TEMP.comision_cartera_JSM`
WHERE comision_calculada IS NULL OR comision_calculada = 0;



END