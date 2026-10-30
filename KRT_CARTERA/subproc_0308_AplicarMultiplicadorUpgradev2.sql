BEGIN
    ----============================================================================================================================================================================================---- 
    ---- MODULO QUE AÑADE UN NUEVO ATRIBBUTO EN LA TABLA QUE REGISTRA EL VALOR DEL IMPORTE DEL UNITARIO RESULTANTE DE APLICAR UN FACTOR MULTIPLICADOR A TODS OS EVENTOS COMSIIONABLES EN TELEVENTA  ----
    ----============================================================================================================================================================================================----     

    --- PASO 1: APLICO MULTIPLICADOR A EVENTOS DE CAMPAÑAS PARAMETRIZADAS (HOJA CAMPANA) CON VALOR DE MULTIPLICADOR UPGRADE INFORMADO (CAMPO MULTIPLICADOR_UPG). 
    ---         A LOS EVENTOS NO RELACIONADOS SE LES APLICA UN FACTOR DE PONDERACION DE 1

      --- PASO 1.1: SE APLICA MULTIPLICADOR A EVENTOS CON ID_CAMPAÑA INFORMADO

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL_ID_CMP` AS
      SELECT a.*, SAFE_MULTIPLY(a.importe , coalesce(c.multiplicador_upg, 1)) as importe_nivel
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` a
      LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
      ON UPPER(a.marca_ds) = c.marca_ds AND a.campana_id = c.campana_id AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1 = 1 ELSE a.nombre_distribuidor = c.nombre_distribuidor END
      where a.campana_id is not null;

      --- PASO 1.2: SE APLICA MULTIPLICADOR A EVENTOS CON MOBRE DE AMPAÑA INFORMADO E ID_CAMPAÑA NO INFORMADO
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL_NOMBRE_CMP` AS
      SELECT a.*, SAFE_MULTIPLY(a.importe , coalesce(c.multiplicador_upg, 1)) as importe_nivel
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` a
      LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
      ON UPPER(a.marca_ds) = c.marca_ds AND a.nombre_campana = c.nombre_campana AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1 = 1 ELSE a.nombre_distribuidor = c.nombre_distribuidor END
      WHERE NOT EXISTS (
        SELECT 1 
        FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL_ID_CMP` r
        where r.marca_ds=a.marca_ds and r.idFijo=a.idFijo and r.IdProducto=a.idProducto
      )
      and a.nombre_campana is not null;
      

      --- PASO 1.3: SE CREA TABLA QEU CONTIENE LA POBLACION DE  EVENTOS CON IDENTIFICATIVO O NOMBRE DE CAMPAÑA INFORMADO
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL` AS
      SELECT * from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL_ID_CMP`
      UNION ALL
      SELECT * from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL_NOMBRE_CMP`
      order by marca_ds, idFijo, IdProducto;


      --- PASO 1.4: SE CREA TABLA QEU CONTIENE LA POBLACION DE EVENTOS SIN IDENTIFICATIVO NIO NOMBRE DE CAMPAÑA INFORMADO A LOS QUE SE APLICA EN MR TELEVENTAS UPG
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_UNITARIOS_TLV_UPG_SIN_CAMPANA` AS 
      SELECT distinct * 
      --FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL`
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS`
      WHERE campana_id is null and nombre_campana is null
      --AND marca_ds="TELECABLE"
      AND MARCO_RETRIBUTIVO='MR Televenta_UPG';

      --- PASO 1.5: SE CREA TABLA QEU CONTIENE LA POBLACION DE EVENTOS SIN IDENTIFICATIVO NIO NOMBRE DE CAMPAÑA INFORMADO A LOS QUE SE APLICA EN MR TELEVENTAS UPS
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_UNITARIOS_TLV_UPS_SIN_CAMPANA` AS 
      SELECT distinct * 
      --FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL`
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS`    
      WHERE campana_id is null and nombre_campana is null
      --AND marca_ds="TELECABLE"
      AND MARCO_RETRIBUTIVO='MR Televenta_UPS';


      --- PASO 1.6: SE CREA TABLA QUE CONTIENE TODOS LOS EVENTOS
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` AS
      SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL`
      UNION ALL select distinct *, importe  from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_UNITARIOS_TLV_UPG_SIN_CAMPANA` 
      UNION ALL select distinct *, importe from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_UNITARIOS_TLV_UPS_SIN_CAMPANA` ;    


    --- PASO 2: APLICO PONDERACION SEGUN PARAMETRIZACION ESTATICA DE FACTOR DE PONDERACIONN A POBLACION DE TELEVENTAS UPGRADING SIN CAMPAÑA

      --- PASO 2.1 IDENTIFICO POBLACION OBJETIVO
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` AS 
      SELECT distinct t.* except(importe_nivel), SAFE_MULTIPLY(t.importe , coalesce(p.multiplicador_upg, 1)) as importe_nivel 
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` t
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_MULTIPLICADOR_TVT_UPG_SIN_CAMPANA`  p
      on TRIM(UPPER(t.marca_ds))=TRIM(UPPER(p.marca_ds))  AND t.MARCO_RETRIBUTIVO='MR Televenta_UPG' AND t.campana_id is null AND t.nombre_campana is null;


      --- PASO 2.2: EXCLUYO EVENTOS CONCRETOS (contingencias en su día) 
        --- PARCHE TEMPORAL
      delete from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` where idProductoOrigen=14015185218;
      delete from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` where idProducto in(60038226100, 60038226116, 60054818338, 60091352760);

        ----  FIN PARCHE TEMPORAL

      ---- PARCHE 20240119
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD` AS 
      select u.marca_ds,u.idFijo,u.idProducto, count(u.concepto_ds)  as nreg
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` b 
      inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` u
      on TRIM(UPPER(u.marca_ds))=TRIM(UPPER(b.marca_ds))
      AND u.idFijo=b.idFijo
      AND u.idProducto=b.idProducto
      AND u.TipoMovimiento=b.TipoMovimiento
      AND u.concepto_ds=b.Concepto_ds
      AND b.MARCO_RETRIBUTIVO='MR Televenta_UPG'
      AND b.campana_id is null 
      and b.nombre_campana is null
      group by 1,2,3
      having  count(u.concepto_ds) >1
      order by 4 desc;


      ---- PARCHE 20250601
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD_2` AS 
      select u.marca_ds,u.idFijo,u.idProducto, count(u.concepto_ds)  over (partition by  u.marca_ds,u.idFijo,u.idProducto)as nreg
      from  `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` b 
      inner join  `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` u
      on TRIM(UPPER(u.marca_ds))=TRIM(UPPER(b.marca_ds))
      AND u.idFijo=b.idFijo
      AND u.idProducto=b.idProducto
      AND u.TipoMovimiento=b.TipoMovimiento
      AND u.concepto_ds=b.Concepto_ds
      AND b.MARCO_RETRIBUTIVO='MR Televenta_UPG'
      AND b.campana_id is null 
      and b.nombre_campana is null
      where NOT EXISTS (
        select 1
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD` d
        where d.marca_ds=u.marca_ds and d.idFijo=u.idFijo and d.idProducto=u.idProducto
      )
      qualify ROW_NUMBER() over(partition by b.idfijo, b.idProducto, b.TipoMovimiento, b.concepto_ds, b.marco_retributivo)>1;



      -- PASO 2.3: APLICO FACTOR DE PONDERACION 
      UPDATE  `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` b 
      SET b.importe_nivel=u.importe_nivel
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` u
      WHERE TRIM(UPPER(u.marca_ds))=TRIM(UPPER(b.marca_ds))
      AND u.idFijo=b.idFijo
      AND u.idProducto=b.idProducto
      AND u.TipoMovimiento=b.TipoMovimiento
      AND u.concepto_ds=b.Concepto_ds
      AND b.MARCO_RETRIBUTIVO='MR Televenta_UPG'
      AND b.campana_id is null 
      and b.nombre_campana is null
      AND NOT EXISTS (
        select 1
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD` d
        where d.marca_ds=u.marca_ds and d.idFijo=u.idFijo and d.idProducto=u.idProducto
      ) 
      AND NOT EXISTS (
        select 1
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD_2` d
        where d.marca_ds=u.marca_ds and d.idFijo=u.idFijo and d.idProducto=u.idProducto
      ) 
      ;
      
      ---- FIN PARCHE 20240119

    --- PASO 3: Creo tabla  LOG_0308_BONOS_TELEVENTAS_FINAL
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL`;



  END