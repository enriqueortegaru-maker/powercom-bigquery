BEGIN

    /*PASO 1: IDENTIFICO OFERTAS ASOCIADAS A VENTAS*/
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS` AS 
    select distinct v.*, ct.catalogo_id as catalogo_oferta_id
    from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_npc_solicitud` sl
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_co_pedido` pd on pd.swCustomerId=sl.swCustomerId  and pd.swAgreementId=sl.swAgreementId and pd.swChnlPartnerId=sl.swChnlPartnerId
    --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_VENTAS_CAPTACION` v on v.cliente_id=sl.swCustomerId  and CAST(v.contrato_id AS STRING)=cast(sl.swAgreementId as string) and v.pedido=cast(pd.coPedidoId AS STRING)
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v on v.cliente_id=sl.swCustomerId  and CAST(v.contrato_id AS STRING)=cast(sl.swAgreementId as string) and v.pedido=cast(pd.coPedidoId AS STRING)
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` ct  ON ct.adicional_lg = 0 AND ct.tipo_identificacion_ds = 'OFERTA'  AND ct.marca_ds =v.marca_ds  AND ct.catalogo_id=CAST(sl.npcOfertaId AS STRING) and ct.categoria_servicio_ds=v.categoria_servicio_ds
    order by 1,2,3;


    /*PASO 2: ACTUALIZO EL CONCEPTO ASOCIADO A LA OFERTA*/

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS` o 
    SET o.concepto_ds= c.concepto_ds     
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c
    where TRIM(UPPER(c.tipo_identificacion_ds))='OFERTA' 
    and o.marca_ds=c.marca_ds and o.categoria_servicio_ds=c.categoria_servicio_ds and o.tecnologia_detalle_ds=c.tecnologia_detalle_ds and o.catalogo_oferta_id=c.catalogo_id;
    


    /*PASO 3: CARACTERIZO REGISTROS DE OFERTAS*/
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS` SET grid=9 where 1=1;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS` 
    SET desc_mm= `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_comisionesv1`(categoria_servicio_ds, concepto_ds,portabilidad_in_lg, grid)   
    where grid=9;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS` 
    SET clase_mm= `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(desc_mm)   
    where grid=9;

    /*PASO 4: INSERTO OFERTAS EN REGISTRO DE VENTAS*/    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  SELECT * except(catalogo_oferta_id) FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_OFERTAS`; 


    /*PASO 5: GENERO LOG*/        
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_011020_VENTAS_CAPTACION` AS 
    SELECT * except(catalogo_oferta_id) FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

END