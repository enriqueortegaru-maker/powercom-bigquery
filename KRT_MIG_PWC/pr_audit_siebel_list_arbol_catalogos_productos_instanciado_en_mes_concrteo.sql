BEGIN

    DECLARE VMES INT64; 
--- LOCALDECLARE VDESDE INT64; SET VDESDE = 20250901; 
    SET VMES = CAST(FORMAT_DATE("%Y%m", DATE_TRUNC(PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)), MONTH)) AS INT64);
  -- DECLARE VANNO INT64;DECLARE VLINENAME STRING; SET VANNO=2025; SET VLINENAME="TELEVISION";


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AUDIT_SIEBEL_LIST_ARBOL_PRODUCTOS_INSTANCIADOS_MES_CONCRETO` AS   
    -- La palabra clave RECURSIVE se coloca aquí, al inicio de todo el bloque WITH.
    WITH RECURSIVE 
      -- 1. Se define el CTE 'cp' con los datos base. No es recursivo, pero forma parte del mismo bloque.
      cp AS (
        SELECT 
          CAST(FORMAT_DATE("%Y%m", p.Last_upd) AS INT64) AS mes, 
          p.tipoentidad,
          p.codigopadre, 
          p.codigo,
          p.descripcion,
          ARRAY_TO_STRING(ARRAY_AGG(distinct CONCAT(CAST(f.IDCLIENTE AS  STRING),"-",f.IDCONTRATO)),"#" )as vidcl_ctr,                              
          COUNT(distinct f.IDCLIENTE) AS ncl,
          COUNT(distinct f.IDCONTRATO) AS nctr,          
          COUNT(p.row_id) AS npaq, 
          COUNTIF(p.idexterno IS NULL) AS next_nulo, 
          100 * COUNTIF(p.idexterno IS NULL) / COUNT(p.row_id) AS pctext_nulo, 
          COUNTIF(p.idinterno IS NULL) AS nint_nulo,
          100 * COUNTIF(p.idinterno IS NULL) / COUNT(p.row_id) AS pctint_nulo
        FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p
        INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f
          ON p.idproducto = f.IDPRODUCTONEW
        WHERE 
          CAST(FORMAT_DATE("%Y%m", p.Last_upd) AS INT64) = VMES
          AND f.estado = '5'
        GROUP BY 1, 2, 3, 4, 5
      ),

      -- 2. Ahora se define el CTE recursivo 'j' sin añadir ninguna palabra clave extra.
      j AS (
        -- Miembro ancla (punto de partida de la recursión)
        SELECT 
          ROW_NUMBER() OVER(ORDER BY cp.codigo) AS idreg, 
          1 AS lvl, 
          cp.*
        FROM cp
        WHERE 
          codigopadre IS NULL
          AND tipoentidad = 'PRODUCTO'
          AND mes = VMES

        UNION ALL

        -- Miembro recursivo (la parte que se repite)
        SELECT 
          j.idreg, 
          j.lvl + 1 AS lvl, 
          c.*
        FROM j
        INNER JOIN cp AS c
          ON j.mes = c.mes AND j.codigo = c.codigopadre AND c.codigo != c.codigopadre
        WHERE lvl < 100
      )

    -- 3. Finalmente, se selecciona el resultado del CTE recursivo.
    SELECT * FROM j 
    ORDER BY idreg ASC, lvl ASC;

END