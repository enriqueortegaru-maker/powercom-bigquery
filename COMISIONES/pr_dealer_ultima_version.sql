begin

-- call `mm-commissions-reporting.COMISIONES.pr_dealer_ultima_version`(202610)

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.dealer_ultima_version` AS 

select *
from COMISIONES.v_dealer 
where NOT(DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes AS STRING)), MONTH) >= DATE_TRUNC(CURRENT_DATE(), MONTH))
and not (comentarios = 'NUEVO PRELIQUI' and cif is null)
qualify row_number () over (partition by sfid_id order by id_mes desc) = 1

union all

select *
from COMISIONES.v_dealer 
where agrupacion_canal = 'Exclusivo'
and comentarios = 'NUEVO PRELIQUI'
and cif is null ;

end