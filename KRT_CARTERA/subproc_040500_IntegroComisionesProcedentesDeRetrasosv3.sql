BEGIN

  -- CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0408_CrearComisiones_Listadov4`(20260101);
  DECLARE VFECHA_ACTIVACION_DT DATE;
  DECLARE VMES_PREVIO DATE;

  SET VFECHA_ACTIVACION_DT = PARSE_DATE("%Y%m%d", CAST(desde AS STRING));
  SET VMES_PREVIO = DATE_SUB(DATE_TRUNC(VFECHA_ACTIVACION_DT, MONTH), INTERVAL 1 MONTH);
  
  IF (SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS`) > 0 THEN 

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` AS
      WITH 
        -- 1. Validadores (Mes Previo)
        valid_conceptos AS (
            SELECT DISTINCT concepto 
            FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
            WHERE mes_factura_dt = VMES_PREVIO
        ),
        valid_clases AS (
            SELECT DISTINCT clase_concepto 
            FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
            WHERE mes_factura_dt = VMES_PREVIO
        ),

        -- 2. Normalización de Retrasos (stg_retrasos)
        -- CORRECCIÓN: Convertimos explícitamente TIMESTAMP a DATE aquí
        stg_retrasos AS (
            SELECT DISTINCT
                r.* EXCEPT(Fecha_Activacion, Fecha_Creacion, Antiguedad), -- Excluimos los originales para reemplazarlos
                EXTRACT(DATE FROM r.Fecha_Activacion) as Fecha_Activacion, -- Conversión a DATE
                EXTRACT(DATE FROM r.Fecha_Creacion) as Fecha_Creacion,     -- Conversión a DATE
                EXTRACT(DATE FROM r.Antiguedad) as Antiguedad,             -- Conversión a DATE
                
                -- Campos para joins
                UPPER(TRIM(marca_ds)) as join_marca,
                UPPER(TRIM(IdCatalogo)) as join_id_catalogo,
                UPPER(TRIM(NombreProducto)) as join_nombre_producto
            FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS` r
        ),
        
        -- 3. Enriquecimiento (enriched_data)
        enriched_data AS (
            SELECT 
                r.* EXCEPT(join_marca, join_id_catalogo, join_nombre_producto),
                COALESCE(cat.NombreProducto, t.MODELO, r.NombreProducto) as NombreProducto_Calc,
                COALESCE(cat.TipoProducto, t.clase) AS ClaseProducto_Calc,
                `mm-commissions-reporting.KRT_CARTERA.f_crea_TipoProducto`(
                    COALESCE(cat.TipoProducto, t.clase), 
                    COALESCE(cat.tipo_movimiento, NULL), 
                    r.concepto_ds, 
                    COALESCE(cat.NombreProducto, t.MODELO)
                ) as TipoProducto_Calc
            FROM stg_retrasos r
            LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat
                ON UPPER(TRIM(cat.marca_ds)) = r.join_marca
                AND (
                    (r.join_marca != 'R' AND r.IdCatalogo != '6851' AND UPPER(TRIM(cat.idProdCat)) = r.join_id_catalogo)
                    OR 
                    (r.join_marca = 'R' AND UPPER(TRIM(cat.idProdCat)) = r.join_id_catalogo)
                )
            LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` t 
                ON UPPER(TRIM(t.MODELO)) = r.join_nombre_producto
                AND r.join_marca != 'R' 
                AND r.IdCatalogo = '6851'
        ),

        -- 4. Cálculo de desc_mm
        calculated_mm AS (
            SELECT 
                e.*,
                CASE 
                    WHEN vc.concepto IS NOT NULL THEN e.desc_mm 
                    ELSE `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv2`(
                        TipoMovimiento, concepto_ds, NombreProducto_Calc, TipoProducto_Calc
                    ) 
                END as desc_mm_base
            FROM enriched_data e
            LEFT JOIN valid_conceptos vc ON vc.concepto = e.desc_mm
        ),

        -- 5. Cálculo de clase_mm
        final_logic AS (
            SELECT 
                c.*,
                CASE 
                    WHEN vcl.clase_concepto IS NOT NULL THEN c.clase_mm 
                    ELSE `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(c.desc_mm_base)
                END as clase_mm_base
            FROM calculated_mm c
            LEFT JOIN valid_clases vcl ON vcl.clase_concepto = c.clase_mm
        )

      -- 6. Selección Final
      -- Ahora Fecha_Activacion es DATE, por lo que la comparación funcionará correctamente
      SELECT DISTINCT
          marca_ds, IdCatalogo, NombreProducto_Calc as NombreProducto, nombre_distribuidor, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto_Calc as ClaseProducto, TipoProducto_Calc as TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, mes_comision_id,
          
          CASE 
            WHEN NOT(Fecha_Activacion >= VFECHA_ACTIVACION_DT AND Fecha_Activacion <= LAST_DAY(VFECHA_ACTIVACION_DT, MONTH)) 
            THEN REPLACE(desc_mm_base, LEFT(desc_mm_base, 4), 'Y - ') 
            ELSE desc_mm_base 
          END as desc_mm,

          CASE 
            WHEN NOT(Fecha_Activacion >= VFECHA_ACTIVACION_DT AND Fecha_Activacion <= LAST_DAY(VFECHA_ACTIVACION_DT, MONTH)) 
            THEN 'Y - Retrasos'
            ELSE clase_mm_base 
          END as clase_mm,
          
          orden_sap
      FROM final_logic;


      ----------------------------------------------------------------------------
      -- PASO FINAL: INSERTAR
      ----------------------------------------------------------------------------
      INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES` (
          marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, mes_comision_id, desc_mm, clase_mm, orden_sap
      )
      SELECT DISTINCT 
          marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, mes_comision_id, desc_mm, clase_mm, orden_sap
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES`;

  END IF;

END