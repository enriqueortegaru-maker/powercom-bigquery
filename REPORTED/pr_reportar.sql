begin

-- call REPORTED.pr_reportar ('MCOM 0223', 'exclusivo', null, '2023-01-01');

declare sql, tabla_final, tabla_destino, tabla_detalle, id_tabla  string;

set id_tabla = ifnull ( (select max(CAST(id_tabla+1 AS STRING FORMAT '00')) from REPORTED.v_tablas_comisiones where mes = mes_pr and UPPER(canal) = UPPER(canal_pr)) , '01');

set id_tabla = replace (id_tabla, ' ', '');

if subcanal is null then 
set tabla_detalle = upper(canal_pr)||'.comisiones_working_sap';
else 
set tabla_detalle = upper(canal_pr)||'.comisiones_working_sap'||'_'||lower(subcanal);
end if;

set tabla_destino = 'REPORTED.sap_'||lower(canal_pr)||'_'||format_date ('%Y%m', mes_pr)||id_tabla;

set tabla_final = replace (tabla_destino, 'sap', 'comisiones');

set sql =        'assert not exists ( select 1 ';
set sql = sql || ' from `mm-commissions-reporting.REPORTED.sap_';
set sql = sql || lower(canal_pr);
set sql = sql || '*`';
set sql = sql || ' where ZIDPROC = "';
set sql = sql || proceso_mcom;
set sql = sql || '"';
set sql = sql || ' );';

execute immediate (sql);

set sql =        'assert exists ( select 1 ';
set sql = sql || ' from `mm-corporate-triki-prod.sap4hana.ZFAP_E016_POS`';
set sql = sql || ' where ZIDPROC = "';
set sql = sql || proceso_mcom;
set sql = sql || '"';
set sql = sql || ' );';

execute immediate (sql);

set sql =        'assert not exists ( select 1 from ';
set sql = sql || tabla_detalle;
set sql = sql || ' a ';
set sql = sql || 'left join `mm-corporate-triki-prod.sap4hana.ZFAP_E016_POS` b ';
set sql = sql || 'on a.id_registro = b.zidreg  ';
set sql = sql || 'where b.zidreg is null ';
set sql = sql || 'and b.ZSTAT in("W","S") and b.XBLNR is not null ' ;
set sql = sql || 'and b.ZIDPROC = "' ;
set sql = sql || proceso_mcom ;
set sql = sql || '" ';
set sql = sql || ');';

execute immediate (sql);

set sql =        'create table ';
set sql = sql || tabla_destino;
set sql = sql || ' as ';
set sql = sql || ' select ';
set sql = sql || ' b.XBLNR AS INVOICE_ID, ';
set sql = sql || ' ZIDPROC AS proceso_sap, ';
set sql = sql || ' * ';
set sql = sql || ' from ';
set sql = sql || tabla_detalle;
set sql = sql || '  a ';
set sql = sql || '  inner join `mm-corporate-triki-prod.sap4hana.ZFAP_E016_POS`  b on a.id_registro = b.ZIDREG  ';
set sql = sql || '  where 1=1 ';
set sql = sql || ' and b.ZSTAT in("W","S") ';
set sql = sql || ' and b.XBLNR is not null ';
set sql = sql || ' and b.ZIDPROC = "' ;
set sql = sql || proceso_mcom ;
set sql = sql || '" ;';

execute immediate (sql);

set sql = ' create table ';
set sql = sql || tabla_final;
set sql = sql || ' as ';
set sql = sql || ' select ';
set sql = sql || ' id_registro ';				
set sql = sql || ' ,sociedad ';				
set sql = sql || ' ,id_comisionista ';					
set sql = sql || ' ,tipo_comisionista ';					
set sql = sql || ' ,CIF ';					
set sql = sql || ' ,zona_fiscal ';					
set sql = sql || ' ,tipo_concepto ';					
set sql = sql || ' ,descripcion_concepto ';					
set sql = sql || ' ,b.uds ';					
set sql = sql || ' ,b.importe_base ';					
set sql = sql || ' ,moneda ';					
set sql = sql || ' ,via_pago ';					
set sql = sql || ' ,cond_pago ';					
set sql = sql || ' ,cod_canal ';					
set sql = sql || ' ,cod_producto ';					
set sql = sql || ' ,cod_tipo_contrato  ';
set sql = sql || ' ,cod_marca ';
set sql = sql || ' ,cod_operador ';
set sql = sql || ' ,cod_segmento  ';					
set sql = sql || ' ,facturador  ';					
set sql = sql || ' ,clasificacion_concepto	 ';				
set sql = sql || ' ,canal	 ';				
set sql = sql || ' ,subscription_id			 ';		
set sql = sql || ' ,product_type  ';					
set sql = sql || ' ,bundle_type	 ';				
set sql = sql || ' ,msisdn	 ';				
set sql = sql || ' ,fecha_activacion ';					
set sql = sql || ' ,fecha_baja	 ';				
set sql = sql || ' ,account_id	 ';				
set sql = sql || ' ,customer_id	 ';				
set sql = sql || ' ,sale_dealer sfid_unico ';					
set sql = sql || ' ,tienda	 ';				
set sql = sql || ' ,distribuidor ';					
set sql = sql || ' ,fecha	 ';				
set sql = sql || ' ,agrupacion_cod_tipo_contrato	 ';				
set sql = sql || ' ,segmento	 ';				
set sql = sql || ' ,razon_social ';					
set sql = sql || ' ,nombre_comercio	 ';				
set sql = sql || ' ,marca	 ';				
set sql = sql || ' ,INVOICE_ID	 ';				
set sql = sql || ' ,order_id ';					
set sql = sql || ' ,Product_Id	 ';				
set sql = sql || ' ,Product	 ';				
set sql = sql || ' ,user_id ';
set sql = sql || ' ,campaign_code ';					
set sql = sql || ' ,claim_code ';				
set sql = sql || ' ,process_code ';				
set sql = sql || ' ,comments ';
set sql = sql || ' ,substr(id_registro_interno,1,4) as proceso ';
set sql = sql || ' ,ZIDPROC as proceso_sap ';
set sql = sql || ' from  ';
set sql = sql || tabla_destino;
set sql = sql || ' a , unnest (trazabilidad) b';

execute immediate (sql);

set sql = ' drop table ';
set sql = sql || tabla_detalle;
set sql = sql || ' ; ';

execute immediate (sql);

call  REPORTED.pr_trazabilidad ();

end