begin

declare sql , prefijo , mes_string string;

declare canales_pr ARRAY <STRING> DEFAULT ['XS','XSO'];

set prefijo = 'XSRP';

set mes_string = cast(mes_int as string);

-- call `mm-commissions-reporting.COMISIONES.pr_xsrp` (202409);

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.TEMP.xsrp` AS
SELECT
  a.* EXCEPT (concepto,
    comision,
    commission_id,
    mes_liquidado,
    facturador,
    tipo_concepto,
    comments,
    id_mes),
 
  prefijo||'D'||'_'||mes_string||'_'||a.canal||'_'||row_number () OVER () AS commission_id,

  CASE

    WHEN c.concepto = 'D - Rappel Fijo'  and a.concepto = 'A - Servicio Fijo' and
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_fijo

    WHEN c.concepto = 'D - Rappel Movil' and a.concepto = 'A - Servicio Movil Pospago' and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_movil

    WHEN c.concepto = 'D - Rappel TV' and a.concepto in  ('B - Television','B - Television Premium') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_tv 

    WHEN c.concepto = 'D - Rappel Renuevo' and a.concepto in  ('B - Renuevo') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_renuevo    

  end AS comision,

  c.concepto,

  c.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
  'C_MANUAL' AS facturador,

  cast (null as string ) as comments

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` a
INNER JOIN
  `mm-commissions-reporting.GS.MARCO_RAPPEL_XS` b
ON
  a.id_comisionista=b.id_comisionista
  AND b.mes = mes_int
CROSS JOIN
  `mm-commissions-reporting.GS.CONCEPTOS` c
WHERE
  a.canal IN ('XS','XSO')
  AND c.proceso like '%XSRP%'
  AND a.concepto in ( 'A - Servicio Fijo', 'A - Servicio Movil Pospago', 'B - Television','B - Television Premium', 'B - Renuevo')
  AND a.id_mes = mes_int
  and
  CASE

    WHEN c.concepto = 'D - Rappel Fijo'  and a.concepto = 'A - Servicio Fijo' and
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_fijo

    WHEN c.concepto = 'D - Rappel Movil' and a.concepto = 'A - Servicio Movil Pospago' and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_movil

    WHEN c.concepto = 'D - Rappel TV' and a.concepto in  ('B - Television','B - Television Premium') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_tv  

    WHEN c.concepto = 'D - Rappel Renuevo' and a.concepto in  ('B - Renuevo') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_renuevo    

  end > 0
  QUALIFY ROW_NUMBER() OVER (PARTITION BY a.concepto, a.service_id, a.marca, a.service_type) = 1
;

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.TEMP.xsrp_clawback` AS

SELECT
  a.* EXCEPT (concepto,
    comision,
    commission_id,
    mes_liquidado,
    facturador,
    tipo_concepto,
    comments,
    id_mes),
 
  prefijo||'E'||'_'||mes_string||'_'||a.canal||'_'||row_number () OVER () AS commission_id,

  CASE

    WHEN c.concepto = 'E - Clawback Rappel TV' and a.concepto in  ('B - Television','B - Television Premium') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_tv * -1   

  end AS comision,

  c.concepto,

  c.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
  'C_MANUAL' AS facturador,

  cast (null as string ) as comments

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` a
INNER JOIN
  `mm-commissions-reporting.GS.MARCO_RAPPEL_XS` b
ON
  a.id_comisionista=b.id_comisionista
  AND b.mes = mes_int
CROSS JOIN
  `mm-commissions-reporting.GS.CONCEPTOS` c
WHERE
  a.canal IN ('XS','XSO')
  AND c.proceso like '%XSRP%'
  AND a.concepto in ( 'B - Television','B - Television Premium')
  AND a.id_mes = mes_int
  AND DATE_TRUNC(a.deactivation_date, MONTH) = COMISIONES.f_mes_int (mes_int) 
  AND
  CASE
    
    WHEN c.concepto = 'E - Clawback Rappel TV' and a.concepto in  ('B - Television','B - Television Premium') and 
    coalesce (b.camp, 'NULO') = case when b.camp is null then 'NULO' else a.campaign_code end
    then b.rappel_tv    

  end > 0
;

-- Inserta tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('XSRPD', mes_int, canales_pr , 'TEMP.xsrp' , 'ACTUALIZAR');
call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('XSRPE', mes_int, canales_pr , 'TEMP.xsrp_clawback' , 'ACTUALIZAR');

end