BEGIN

    --- PASO 1: Creo tabla LOG_0308_BONOS_TELEVENTAS_INICIAL
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL` AS
    SELECT a.*, SAFE_MULTIPLY(a.importe , coalesce(c.multiplicador_upg, 1)) as importe_nivel
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
    ON UPPER(a.marca_ds) = c.marca_ds AND a.campana_id = c.campana_id AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1 = 1 ELSE a.nombre_distribuidor = c.nombre_distribuidor END;



    --- PASO 2: Creo tabla LOG_0308_UNITARIOS_TLV_UPG_SIN_CAMPAÑA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_UNITARIOS_TLV_UPG_SIN_CAMPANA` AS 
    SELECT distinct * 
    FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL`
    WHERE campana_id is null
    --AND marca_ds="TELECABLE"
    AND MARCO_RETRIBUTIVO='MR Televenta_UPG';



    --- PASO 3: Creo tabla  LOG_0308_BONOS_TELEVENTAS_FINAL
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL`;


    --- PASO 4: Actualizo importes en tabla  LOG_0308_BONOS_TELEVENTAS_FINAL

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` AS 
    SELECT distinct t.* except(importe_nivel), SAFE_MULTIPLY(t.importe , coalesce(p.multiplicador_upg, 1)) as importe_nivel 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_INICIAL` t
    inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_MULTIPLICADOR_TVT_UPG_SIN_CAMPANA`  p
    on TRIM(UPPER(t.marca_ds))=TRIM(UPPER(p.marca_ds))  AND t.MARCO_RETRIBUTIVO='MR Televenta_UPG' AND t.campana_id is null ;


    ---- PARCHE TEMPORAL
    delete from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` where idProductoOrigen=14015185218;
    delete from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` where idProducto in(60038226100, 60038226116, 60054818338, 60091352760);

    ----  FIN PARCHE TEMPORAL

    ---- PARCHE 20240119
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD` AS 
    select u.marca_ds,u.idFijo,u.idProducto, count(u.importe)  as nreg
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL` b 
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_UPD` u
    on TRIM(UPPER(u.marca_ds))=TRIM(UPPER(b.marca_ds))
    AND u.idFijo=b.idFijo
    AND u.idProducto=b.idProducto
    AND u.TipoMovimiento=b.TipoMovimiento
    AND u.concepto_ds=b.Concepto_ds
    AND b.MARCO_RETRIBUTIVO='MR Televenta_UPG'
    AND b.campana_id is null
    group by 1,2,3
    having  count(u.importe) >1
    order by 4 desc;


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
    AND NOT EXISTS (
      select 1
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_EXCLUIDOS_POR_DUPLICIDAD` d
      where d.marca_ds=u.marca_ds and d.idFijo=u.idFijo and d.idProducto=u.idProducto
    );
    
    ---- FIN PARCHE 20240119

    --- PASO 5: Creo tabla  LOG_0308_BONOS_TELEVENTAS_FINAL
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS_FINAL`;



  END