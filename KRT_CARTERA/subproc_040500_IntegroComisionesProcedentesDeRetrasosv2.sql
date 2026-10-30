BEGIN

  --- MODIFICACION 20251130:Se modifican filas 219 y 222 para calculo correcto de ClaseDeProducto asociado a retraso

  DECLARE VFECHA_ACTIVACION_DT DATE;
  --DECLARE DESDE INT64;  SET DESDE=20251101;
  SET VFECHA_ACTIVACION_DT=PARSE_DATE("%Y%m%d",CAST(DESDE AS STRING));

  ---EN DESARROLLO
  
  IF((select count(*) from `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS`) >0 ) THEN 


      --- PASO 1: LEO RETRASOS EN TABLA LOG

      ---- PENDIENTE INTEGRARA CALCULO DE MES_COMISION_ID EN BASE A FECHA ACTIVACION
      
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES`  AS 
      select distinct 
        marca_ds,
        IdCatalogo,
        NombreProducto,
        nombre_distribuidor,
        Canal,
        subcanal,
        agente,
        IdFijo,
        Antiguedad,
        DNI_CIF,
        Marca_Cartera,
        Fecha_Activacion,
        Fecha_Creacion,
        Segmento,
        Subsegmento,
        idCatalogoOrigen,
        IdProductoOrigen,
        NombreProductoOrigen,
        TipoMovimiento,
        IdProducto,
        Contrato,
        UsuarioCreador,
        agente_creador_id,
        concepto_ds,
        concepto_origen_ds,
        medio_conocimiento,
        TipoProducto,
        clave_mr,
        MARCO_RETRIBUTIVO,
        tvt_ups_virgin,
        televenta,
        importe,
        nivel,
        importe_nivel,
        bono_comercial,
        bono_calidad,
        bono_extras,
        total,
        campana_id,
        nombre_campana,
        decomisionable,
        decom_bono_extra,
        mes_comision_id,
        desc_mm,
        clase_mm,
        orden_sap
      from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
      where 1=2;


      INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` 
      SELECT distinct
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      EXTRACT(DATE FROM Antiguedad),
      DNI_CIF,
      Marca_Cartera,
      EXTRACT(DATE FROM Fecha_Activacion),
      EXTRACT(DATE FROM Fecha_Creacion),
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      TipoProducto,
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      orden_sap
      FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS`;



      --- PASO 2: ACTUALIZO EL VALOR DE LOS CAMPOS CLASE Y TIPO PRODUCTO

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES`  AS 
      SELECT distinct 
      c.marca_ds,
      c.IdCatalogo,
      coalesce(cat.NombreProducto, t.MODELO) as NombreProducto,
      c.nombre_distribuidor,
      c.Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      agente_creador_id,
      c.concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,

      --- =================== MODIFICACION
--      coalesce(`mm-commissions-reporting.KRT_CARTERA.f_desc_ClaseProducto`(marca_ds, NombreProducto), 'Terminal'),
      COALESCE(cat.TipoProducto, t.clase) AS ClaseProducto,
      --- =================== FIN MODIFICACION

      --- =================== MODIFICACION
--      `mm-commissions-reporting.KRT_CARTERA.f_crea_TipoProducto`(coalesce(`mm-commissions-reporting.KRT_CARTERA.f_desc_ClaseProducto`(marca_ds, NombreProducto), 'Terminal', TipoMovimiento, concepto_ds, NombreProducto),
      `mm-commissions-reporting.KRT_CARTERA.f_crea_TipoProducto`(COALESCE(cat.TipoProducto, t.clase), coalesce(cat.tipo_movimiento, t.tipo), c.concepto_ds, cat.NombreProducto) as TipoProducto,
    
    --- =================== FIN MODIFICACION      
      --TipoProducto,
/*      
      ---PARCHE TEMPORAL POR DUPLICADOS EN NOMBRE CATALOGO PRODUCTOS
      CAST(NULL AS STRING),
      CAST(NULL AS STRING),
      ---FIN PARCHE TEMPORAL
*/      
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      orden_sap
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` c
      LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat
      ON UPPER(TRIM(cat.marca_ds)) = UPPER(TRIM(c.marca_ds))
        AND (            
            (
                UPPER(TRIM(c.marca_ds)) != 'R' 
                AND c.idCatalogo != '6851'
                AND UPPER(TRIM(cat.idProdCat)) = UPPER(TRIM(c.idCatalogo))
                -- Si realmente quisiste: AND UPPER(TRIM(cat.NombreProducto)) = UPPER(TRIM(c.NombreProducto))
            )
            OR (
                UPPER(TRIM(c.marca_ds)) = 'R' 
                AND UPPER(TRIM(cat.idProdCat)) = UPPER(TRIM(c.idCatalogo))
            )
        )
      LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` t 
      ON UPPER(TRIM(t.MODELO)) = UPPER(TRIM(c.NombreProducto))
      AND UPPER(TRIM(c.marca_ds)) != 'R' 
      AND c.idCatalogo = '6851';      





      --- PASO 3: INFORMO CLASE_MM DESC_MM Y DESC_MM EN TABLA LOG

      UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` 
      SET desc_mm=`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv2`(TipoMovimiento, concepto_ds, NombreProducto,TipoProducto ) where 1=1;

      UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` 
      SET clase_mm=`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(desc_mm) WHERE 1=1;


      UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` 
      SET clase_mm=case when not(fecha_Activacion>=VFECHA_ACTIVACION_DT and fecha_Activacion<= LAST_DAY(VFECHA_ACTIVACION_DT, MONTH) ) then 'Y - Retrasos'else clase_mm  END WHERE 1=1;
      UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` 
      SET desc_mm=case when not(fecha_Activacion>=VFECHA_ACTIVACION_DT and fecha_Activacion<= LAST_DAY(VFECHA_ACTIVACION_DT, MONTH) ) then replace(desc_mm, LEFT(desc_mm,4),'Y - ') ELSE desc_mm END  WHERE 1=1;



      --- PASO 4: INSERTO REGISTRO EN TABLA COMISIONES
      INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
      (
        marca_ds,
        IdCatalogo,
        NombreProducto,
        nombre_distribuidor,
        Canal,
        subcanal,
        agente,
        IdFijo,
        Antiguedad,
        DNI_CIF,
        Marca_Cartera,
        Fecha_Activacion,
        Fecha_Creacion,
        Segmento,
        Subsegmento,
        idCatalogoOrigen,
        IdProductoOrigen,
        NombreProductoOrigen,
        TipoMovimiento,
        IdProducto,
        Contrato,
        UsuarioCreador,
        agente_creador_id,
        concepto_ds,
        concepto_origen_ds,
        medio_conocimiento,
        ClaseProducto,        
        TipoProducto,
        clave_mr,
        MARCO_RETRIBUTIVO,
        tvt_ups_virgin,
        televenta,
        importe,
        nivel,
        importe_nivel,
        bono_comercial,
        bono_calidad,
        bono_extras,
        total,
        campana_id,
        nombre_campana,
        decomisionable,
        decom_bono_extra,
        mes_comision_id,
        desc_mm,
        clase_mm,
        orden_sap
      )
      SELECT distinct 
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      ClaseProducto,
      TipoProducto,
/*      
      ---PARCHE TEMPORAL POR DUPLICADOS EN NOMBRE CATALOGO PRODUCTOS
      CAST(NULL AS STRING),
      CAST(NULL AS STRING),
      ---FIN PARCHE TEMPORAL
*/      
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      orden_sap
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040500_COMISIONES` ;

      --- PASO 6: ELIMINO POTENCIALES DUPLICADOS
  
      create or replace table`mm-commissions-reporting.KRT_CARTERA.COMISIONES` as 
      SELECT DISTINCT * FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES` ;



  END IF;



END