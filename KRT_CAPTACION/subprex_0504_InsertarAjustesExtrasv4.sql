BEGIN

  --- PASO 1: IDENTIFICAR POBLACION DE EVENTOS SOBRE LOS QUE DISTRIBUIR EXTRAS

    --- PASO 1.1: IDENTIFICAR EVENTOS EXCLUIDOS DE REPARTO
    --- OUT 1.1: LOG_0504_AJUSTES_EVENTOS_EXCLUIDOS_DE_REPARTO     

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_EXCLUIDOS_DE_REPARTO` AS
    select distinct a.*,
    COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds) clientes_subcanal,
    COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds) clientes

    from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` a
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_EXCLUSION_POR_DESC_MM` e
    on e.marca_Ds=a.marca_ds 
    and case when UPPER(TRIM(e.canal))="X" or UPPER(TRIM(e.canal))=UPPER(TRIM(a.canal_alta_ds)) then TRUE ELSE FALSE END
    and case when UPPER(TRIM(e.subcanal))="X" or UPPER(TRIM(e.subcanal))=UPPER(TRIM(a.subcanal_ds)) then TRUE ELSE FALSE END
    and case when UPPER(TRIM(e.marco_retributivo))="X" or UPPER(TRIM(e.marco_retributivo))=UPPER(TRIM(a.marco_retributivo_ds)) then TRUE ELSE FALSE END 
    and UPPER(TRIM(e.desc_mm))=UPPER(TRIM(a.desc_mm)) 
    and UPPER(TRIM(a.categoria_servicio_ds)) = 'BANDA ANCHA' /*and a.marca_ds="EUSKALTEL"and contains_substr(a.desc_mm,'A - Servicio acceso BA') and contains_substr(a.clase_mm,'A - Servicio base')*/;      



    --- PASO 1.2: IDENTIFICAR EVENTOS INCLUIDOS EN REPARTO
    --- OUT 1.2: LOG_0504_AJUSTES_EVENTOS_INCLUIDOS_EN_REPARTO     

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_INCLUIDOS_EN_REPARTO` AS
    with ajTot as (
        SELECT *, 
        COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds) clientes_subcanal_tot,
        COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds) clientes_tot

        FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` a
        WHERE UPPER(TRIM(categoria_servicio_ds)) = 'BANDA ANCHA'
        and contains_substr(desc_mm,'A - Servicio acceso BA') and contains_substr(clase_mm,'A - Servicio base')
        --and marca_ds="EUSKALTEL" and canal_Alta_ds="TASK FORCE"
    ) 
    Select distinct ajTot.*,
    COUNT(*) OVER (PARTITION BY ajTot.marca_ds, ajTot.nombre_distribuidor_alta_ds, ajTot.canal_alta_ds, ajTot.subcanal_ds) clientes_subcanal,
    COUNT(*) OVER (PARTITION BY ajTot.marca_ds, ajTot.nombre_distribuidor_alta_ds, ajTot.canal_alta_ds) clientes
    from ajTot
    where not exists (
      select 1 
      from `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_EXCLUIDOS_DE_REPARTO`  as ajExc
      where UPPER(TRIM(ajTot.marca_ds))=UPPER(TRIM(ajExc.marca_ds)) and ajTot.cliente_id=ajExc.cliente_id and ajTot.servicio_id=ajExc.servicio_id

    )
    --and ajtot.marca_ds="EUSKALTEL" and ajtot.canal_Alta_ds="TASK FORCE"
    ;


  --- PASO 2: DESCUBRIR APUNTES DE DISTRIBUCION DE EXTRAS
  --- OUT 2:  LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR     
    CREATE OR REPLACE TABLE
        `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR` AS

    SELECT
      DISTINCT t.marca_ds,
      t.Cliente_id,
      t.servicio_id,
      t.detalle_servicio_ds,
      CONCAT('Extra por concepto: ', e.CONCEPTO_DS) concepto_ds,
      t.FECHA_RFB_ID,
      t.FECHA_VENTA_NETA_ID,
      t.fecha_rfb_dt,
      t.fecha_venta_neta_dt,
      t.canal_alta_ds,
      t.subcanal_ds,
      t.tipo_canal_alta_ds,
      t.nombre_distribuidor_alta_ds,
      t.agente_alta_id,
      t.agente_creador_id,
      t.categoria_servicio_ds,
      t.cif_nif,
      t.segmento_ds,
      t.subsegmento_ds,
      t.marca_cartera_ds,
      t.Antiguedad_Cliente,
      t.equipo_ds,
      t.territorio_ds,
      t.tecnologia_detalle_ds,
      t.portabilidad_in_lg,
      t.gb,
      t.expediente_id,
      t.expediente_padre_id,
      t.contrato_id,
      t.tipo_pedido_ds,
      t.pedido_id,
      t.tipo_producto_pedido_re_ds,
      t.visibilidad_pedido_lg,
      t.catalogo_id,
  --    t.grid,
  --    t.desc_mm,
  --    t.clase_mm,
      case when t.grid >=0 Then 50 else -50 end as grid,
      'D - Extra' as desc_mm,  
      'D - Extracomision' as clase_mm,
      t.pedido,
      t.nplays,
      t.nplays_rfb,
      t.cat_plays,
      t.cat_plays_rfb,
      t.nplays_p,
      t.nplays_rfb_p,
      t.cat_plays_p,
      t.cat_plays_rfb_p,
      t.clave,
      t.marco_retributivo_ds,
      t.flag_marca_cartera,
      t.grupo_rappel_ds,
      t.orden_sap,
      CASE
        WHEN UPPER(TRIM(e.POR_BA)) = 'S' THEN e.importe
      ELSE
      CASE
        WHEN UPPER(TRIM(e.subcanal_ds)) = 'X' THEN e.importe/clientes
      ELSE
      e.importe/clientes_subcanal
    END
    END
      importe,
      e.decomisionable
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_INCLUIDOS_EN_REPARTO` t
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS`  e
    ON UPPER(TRIM(t.marca_ds)) = UPPER(TRIM(e.marca_ds)) AND UPPER(TRIM(t.nombre_distribuidor_alta_ds)) = UPPER(TRIM(e.nombre_distribuidor_ds)) AND CASE  WHEN UPPER(TRIM(e.subcanal_ds)) <> 'X' THEN UPPER(TRIM(t.subcanal_ds)) = UPPER(TRIM(e.subcanal_ds)) ELSE TRUE END AND UPPER(TRIM(t.canal_alta_ds)) = UPPER(TRIM(e.canal_ds));


  --  UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR` SET clase_mm = 'F - Gestion de canal' WHERE 1=1;
  --  UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR` SET desc_mm = 'F - Extra' WHERE 1=1;  

  --- PASO 3: INSETAR NUEVO APUNTES DE DISTRIBUCION DE EXTRAS EN TABLA AJUSTES_EVENTOS_DEFINITIVOS

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR`;



  --- PASO 4: CREO TABLA DE LOG DE SALIDA DE PASO

      -- Log de fichero completo
      CREATE OR REPLACE TABLE
        `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS` AS
      SELECT 
        * 
      FROM 
        `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`; 


      

  ----
  --
  --  CONTROL DE VERSIONES
  --
  --    v1: 20220628 :Se incluye exclusión de Rappel Llamada, tras modificar flujo, e incluir el concepto_ds 'Rappel Llamada' como nuevo concepto_ds
  --                  Se incluye tabla LOG_0505_AJUSTES_EVENTOS_DEFINITIVOS
  --        

END