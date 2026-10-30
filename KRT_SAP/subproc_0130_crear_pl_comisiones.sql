BEGIN

    DECLARE v_desde, v_param_int INT64;
    DECLARE v_fecha_iteracion DATE;
    DECLARE v_fecha_fin DATE;

    DECLARE v_es_primera_iteracion BOOL DEFAULT TRUE;

    SET v_desde=(select CAST(CAST(FORMAT_DATE('%Y%m%d',min(mes_factura_dt)) AS STRING ) AS INT64) from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`);
    SET v_fecha_iteracion = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(v_desde AS STRING)), MONTH);
    SET v_fecha_fin = DATE_TRUNC(CURRENT_DATE(), MONTH);

    --SELECT V_DESDE,v_fecha_iteracion,v_fecha_fin ;

    LOOP
        IF v_fecha_iteracion >= v_fecha_fin THEN 
            LEAVE; 
        END IF;

        SET v_param_int = CAST(FORMAT_DATE('%Y%m%d', v_fecha_iteracion) AS INT64);

        IF v_es_primera_iteracion THEN
            CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.PL_COMISIONES` partition by mes_factura_dt AS
            SELECT * FROM `mm-commissions-reporting.KRT_SAP`.f_vt_sap_pl_lista_ordenes_de_comisiones_en_mes(v_param_int);           
            SET v_es_primera_iteracion = FALSE;
        ELSE
            INSERT INTO `mm-commissions-reporting.KRT_SAP.PL_COMISIONES`
            SELECT * FROM `mm-commissions-reporting.KRT_SAP`.f_vt_sap_pl_lista_ordenes_de_comisiones_en_mes(v_param_int);
        END IF;

        SET v_fecha_iteracion = DATE_ADD(v_fecha_iteracion, INTERVAL 1 MONTH);
    END LOOP;

END