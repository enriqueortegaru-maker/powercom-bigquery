BEGIN

  --DECLARE hasta, registro, binvocaciondesarrollo INT64;SET hasta=20230731;SET registro=1;SET binvocaciondesarrollo=1;
  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then
    --DECLARE hasta, registro, binvocaciondesarrollo INT64;SET hasta=20230731;SET registro=1;SET binvocaciondesarrollo=1;
    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* --except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_TELEVENTAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_TELEVENTAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_VENTAS_TIENDAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_VENTAS_TIENDAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TELEVENTAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TELEVENTAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` c;	

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TIENDAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TIENDAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(agente_creador_id)
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` c;	


  end if;
    
  END