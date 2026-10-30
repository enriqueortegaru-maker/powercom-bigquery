BEGIN

    DECLARE MES_COMISION INT64;
    SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);

    --- PASO 1 : INTEGRO COMISIONES DE BONOS 
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.BONOS` AS
    SELECT
      * REPLACE(CAST(nivel AS string) AS nivel),
      ifnull(importe_nivel,
        0) + ifnull(bono_comercial,
        0) + ifnull(bono_calidad,
        0) total,
      NULL campana_id,
      '' nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS`
    UNION ALL
    SELECT
      * EXCEPT(campana_id,
        nombre_campana,
        importe,
        importe_nivel,
        nivel_tvt_ups_virgin),
      importe,
      NULL,
      importe_nivel,
      0,
      0,
      ifnull(importe_nivel,
        0) total,
      campana_id,
      nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;


    --- PASO 2 : ENRIQUEZCO REGISTROS CON DATO DE MES DE COMISION
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS`
    ADD COLUMN mes_comision_id INT64;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.BONOS` SET mes_comision_id = MES_COMISION WHERE mes_comision_id is null;

    --- PASO 3 : CLASIFICO BONOS Y CREO TABLA COMISIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT *,
    CASE
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos BA') THEN 'A - Servicio acceso BA'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos telefonia') THEN 'A - Servicio Fijo'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios m') THEN 'A - Servicio Movil Postpago'     
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'portabilidad fijo') THEN 'A - Portabilidad Fijo'      
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'portabilidad m') THEN 'A - Portabilidad Movil Postpago'            
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'B - Netflix'       
      WHEN (CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') or CONTAINS_SUBSTR(TipoMovimiento,'alta alarma')) and CONTAINS_SUBSTR(concepto_ds,'alarma') THEN 'B - Alarma' 
      WHEN (CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') or CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos televis') ) and (CONTAINS_SUBSTR(concepto_ds,'total') or CONTAINS_SUBSTR(concepto_ds,'add-ons tv') or CONTAINS_SUBSTR(concepto_ds,'ocio')  or CONTAINS_SUBSTR(concepto_ds,'replay tv')  or CONTAINS_SUBSTR(concepto_ds,'tv premium') or CONTAINS_SUBSTR(concepto_ds,'pack tv') or (CONTAINS_SUBSTR(concepto_ds,'segunda') and CONTAINS_SUBSTR(concepto_ds,'tv') ) or CONTAINS_SUBSTR(concepto_ds,'deco') ) THEN 'B - Television acceso' 
      WHEN (CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  or CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos televis')) and (CONTAINS_SUBSTR(concepto_ds,'opcion') or CONTAINS_SUBSTR(concepto_ds,'prueba tv') or CONTAINS_SUBSTR(concepto_ds,'bar')  or CONTAINS_SUBSTR(concepto_ds,'estrenos')) THEN 'B - Television contenido'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'wifi') THEN 'B - Wifi'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'tarjeta eco') or CONTAINS_SUBSTR(concepto_ds,'tarjeta sim') ) THEN 'B - Tarjeta Sim'      
      WHEN (CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') or CONTAINS_SUBSTR(TipoMovimiento,'alta seguro mov') or CONTAINS_SUBSTR(TipoMovimiento,'alta seguro móv')) and CONTAINS_SUBSTR(concepto_ds,'seguro movil') THEN 'B - Seguro movil'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'mantenimiento') THEN 'B - Mantenimiento'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'bono') THEN 'B - Bono movil' 
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m')  and CONTAINS_SUBSTR(concepto_ds,'smartwatch') THEN 'B - Smartwatch'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m')  and CONTAINS_SUBSTR(concepto_ds,'wifi') THEN 'B - Wifi'
      WHEN (CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') or CONTAINS_SUBSTR(concepto_ds,'equipamiento m') ) and CONTAINS_SUBSTR(concepto_ds,'plc') THEN 'B - Wifi'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m')  and CONTAINS_SUBSTR(concepto_ds,'mifi') THEN 'B - Mifi'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  and CONTAINS_SUBSTR(concepto_ds,'seguridad') THEN 'B - Seguridad' 
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m')  and CONTAINS_SUBSTR(concepto_ds,'auricular') THEN 'B - Auriculares'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  and CONTAINS_SUBSTR(concepto_ds,'multisim') THEN 'B - Multisim' 
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and (CONTAINS_SUBSTR(concepto_ds,'terminal') or CONTAINS_SUBSTR(concepto_ds,'gama') ) THEN 'B - Terminales'                             
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(TipoProducto,'BANDA ANCHA') and CONTAINS_SUBSTR(concepto_ds,'segunda residencia') THEN 'A - Servicio acceso BA'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  and CONTAINS_SUBSTR(TipoProducto,'FIJA') and CONTAINS_SUBSTR(concepto_ds,'terminal') THEN 'B - Terminales'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  and CONTAINS_SUBSTR(TipoProducto,'BANDA ANCHA') and CONTAINS_SUBSTR(concepto_ds,'ip fija') THEN 'B - Ip Fija'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')  and (CONTAINS_SUBSTR(concepto_ds,'ayud') or CONTAINS_SUBSTR(concepto_ds,'modulo pro')) THEN 'B - Mantenimiento'
      WHEN CONTAINS_SUBSTR(TipoMovimiento,'rappel') THEN 'D - Rappel Teorico'

      ELSE 'OTROS'                   
    end as desc_mm    
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS`;

    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
    ADD COLUMN clase_mm STRING;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'A - Servicio base' WHERE desc_mm like 'A - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'B - SVA' WHERE desc_mm like 'B - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'D - Extracomision' WHERE desc_mm like 'D - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'F - Gestion de canal' WHERE desc_mm like 'F - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'R - Recalculo periodo anterior' WHERE desc_mm like 'R - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SET clase_mm = 'O - Otros' WHERE desc_mm = 'OTROS';    




  --- PASO 3: ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` AS
    SELECT d.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`d 
    inner join `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO` dh
    on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_comision_id!=dh.mes_comision_id;


    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` d
    WHERE EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` dp
      where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
    );
 


  --- PASO 4:ACTUALIZO HISTORICO DE COMISIONES DUPLICADAS EN MESES PREVIOS
    DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    WHERE mes_comision_id=MES_COMISION;

    INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    SELECT * except(agente_creador_id)FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS`;




  --- PASO 5: CREO LOG DE COMISIONES A SALIDA DE ESTE PASO
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES` AS
    SELECT c.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c ;



END