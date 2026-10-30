begin

     declare prefijo, mes_string string;
     declare id_mes_pr int64;  
     declare canales_pr ARRAY<STRING>;   
     --- LOCAL
     --declare desde INT64;set desde=20241201;

     set id_mes_pr=CAST(FLOOR(SAFE_DIVIDE(desde,100)) AS INT64); 
     set mes_string = cast(id_mes_pr as string);
     set canales_pr=NULL;

    --SELECT id_mes_pr, mes_string, canales_pr;

     CALL `mm-commissions-reporting.COMISIONES.pr_ENERGY_GAS_norte_desarrollo`(id_mes_pr, canales_pr);
     CALL `mm-commissions-reporting.COMISIONES.pr_energy_luz_norte_desarrollo`(id_mes_pr);
     CALL `mm-commissions-reporting.COMISIONES.pr_ENERGY_sve_norte_desarrollo`(id_mes_pr, canales_pr);
     CALL `mm-commissions-reporting.COMISIONES.pr_ENERGY_svg_norte_desarrollo`(id_mes_pr, canales_pr);

     select 
          marca,
          -200,
          service_id,
          tariff_ds,
          'Gas',
          CAST(FORMAT_DATE('%Y%m%d', activation_date) AS INT64),
          CAST(FORMAT_DATE('%Y%m%d', sale_date) AS INT64),  
          CAST(activation_date as TIMESTAMP),             
          CAST(sale_date as TIMESTAMP),
          canal,
          agrupacion_canal,
          distribuidor,
          split(seller,'.')[0],
          seller,
          'ENERGIA',
          'RESIDENCIAL',
          'RESIDENCIAL',
          'CARTERA',
          'GAS',
           60,
           'B - Gas',
           'B - SVA',
           serial_number,
           'KRT - Energia',
           110000001948,
           comision,
           'S',
           CAST(CONCAT(mes_string,'01') as INT64)
     from `mm-commissions-reporting.TEMP.ENERGY_GAS_norte`
     where comision is not null ;    


     select 
          marca,
          -100,
          service_id,
          tariff_ds,
          'Electricidad',
          CAST(FORMAT_DATE('%Y%m%d', activation_date) AS INT64),
          CAST(FORMAT_DATE('%Y%m%d', sale_date) AS INT64),  
          CAST(activation_date as TIMESTAMP),             
          CAST(sale_date as TIMESTAMP),
          canal,
          agrupacion_canal,
          distribuidor,
          split(seller,'.')[0],
          seller,
          'ENERGIA',
          'RESIDENCIAL',
          'RESIDENCIAL',
          'CARTERA',
          'ELECTRICIDAD',
           60,
           'B - Electricidad',
           'B - SVA',
           serial_number,           
           'KRT - Energia',
           110000001947,
           comision,
           'S',
           CAST(CONCAT(mes_string,'01') as INT64)
     from `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte`
     where comision is not null ;    



/*   declare prefijo, mes_string string;
     declare id_mes_pr int64;  
     declare canales_pr ARRAY<STRING>;   
     --- LOCAL
     declare desde INT64;set desde=20241201;

     set id_mes_pr=CAST(FLOOR(SAFE_DIVIDE(desde,100)) AS INT64); 
     set mes_string = cast(id_mes_pr as string);
     set canales_pr=NULL;
*/
     select 
          marca,
          -100,
          service_id,
          tariff_ds,
          'Sve',
          CAST(FORMAT_DATE('%Y%m%d', activation_date) AS INT64),
          CAST(FORMAT_DATE('%Y%m%d', sale_date) AS INT64),  
          CAST(activation_date as TIMESTAMP),             
          CAST(sale_date as TIMESTAMP),
          canal,
          agrupacion_canal,
          distribuidor,
          split(seller,'.')[0],
          seller,
          'ENERGIA',
          'RESIDENCIAL',
          'RESIDENCIAL',
          'CARTERA',
          'ELECTRICIDAD',
           60,
           'B - SVE',
           'B - SVA',
           serial_number,           
           'KRT - Energia',
           110000001949,
           comision,
           'S',
           CAST(CONCAT(mes_string,'01') as INT64)
     from `mm-commissions-reporting.TEMP.ENERGY_SVE_norte`
     where comision is not null ;    

     select 
          marca,
          -100,
          service_id,
          tariff_ds,
          'Gas',
          CAST(FORMAT_DATE('%Y%m%d', activation_date) AS INT64),
          CAST(FORMAT_DATE('%Y%m%d', sale_date) AS INT64),  
          CAST(activation_date as TIMESTAMP),             
          CAST(sale_date as TIMESTAMP),
          canal,
          agrupacion_canal,
          distribuidor,
          split(seller,'.')[0],
          seller,
          'ENERGIA',
          'RESIDENCIAL',
          'RESIDENCIAL',
          'CARTERA',
          'GAS',
           60,
           'B - SVG',
           'B - SVA',
           serial_number,           
           'KRT - Energia',
           110000001950,
           comision,
           'S',
           CAST(CONCAT(mes_string,'01') as INT64)
     from `mm-commissions-reporting.TEMP.ENERGY_SVG_norte`
     where comision is not null ;    



end