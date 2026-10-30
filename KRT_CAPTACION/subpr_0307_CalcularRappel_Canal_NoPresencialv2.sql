BEGIN

  DECLARE
    ratio float64;

  SET
    ratio = (
    SELECT
      COUNTIF(tipo_dia = 'LABORABLE') / COUNTIF(tipo_dia = 'LABORABLE'
        AND dia_dt < CURRENT_DATE()) ratio_laborales
    FROM
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
    WHERE
      mes_id IN (
      SELECT
        mes_id
      FROM
        `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
      WHERE
        dia_id = HASTA_ID));

  -- Registro datos en tabla 
  -- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL_NO_PRESENCIAL`

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL`
  ---   `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP`
  ---   `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL`
  ---   

  with vfp as (
    with vf as (
      with   gr as (
        SELECT DISTINCT canal_ds, subcanal_ds,  grupo_rappel as grupo_rappel_ds   
        FROM `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL`
        WHERE TRIM(UPPER(subcanal_ds))='X'
      ) , v as (
        SELECT  *
        FROM  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL`
        WHERE  tipo_canal_alta_ds = 'NO PRESENCIAL'  AND canal_alta_ds <> 'WEB'   AND marca_ds <> 'VIRGIN' 
        -- AÑADIDO
                AND (  (marca_ds IN ('EUSKALTEL', 'RACC','R','TELECABLE')  AND canal_alta_ds <> 'TELEVENTA') 
                    OR marca_ds NOT IN ('EUSKALTEL', 'RACC','R','TELECABLE')
                    )
        --- FIN AÑADIDO 
      )

      SELECT v.*, ifnull(dn.nombre_distribuidor_unificado_ds, v.nombre_distribuidor_alta_ds) as nombre_distribuidor_alta_ds_normalizado
      FROM v 
      INNER JOIN gr
      ON v.canal_alta_ds=gr.canal_ds and  v.grupo_rappel_ds=gr.grupo_rappel_ds
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_DISTRIBUIDORES_NP` as dn
      ON dn.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
      --WHERE v.nombre_distribuidor_alta_ds like '%BERCO%' or v.nombre_distribuidor_alta_ds like '%AVISER%' or v.nombre_distribuidor_alta_ds like '%ENTIA%'
    ) select vf.*,
    --vf.marca_ds,vf.nombre_distribuidor_alta_ds,vf.canal_alta_ds, vf.subcanal_ds, vf.tipo_canal_alta_ds, vf.grupo_rappel,  
    SUM(BAS) OVER (PARTITION BY vf.nombre_distribuidor_alta_ds ) as nBASnorm, 
    SUM(BAS) OVER (PARTITION BY vf.nombre_distribuidor_alta_ds ) * ratio as proyeccion_norm,  
    COUNT(BAS)  OVER (PARTITION BY vf.nombre_distribuidor_alta_ds ) as cBASnorm
    from vf
    order by vf.nombre_distribuidor_alta_ds_normalizado, vf.marca_ds
  )
  select vfp.marca_ds, vfp.nombre_distribuidor_alta_ds,vfp.canal_alta_ds,vfp.subcanal_ds,vfp.grupo_rappel_ds, vfp.nBASnorm as bas,  vfp.proyeccion_norm as proyeccion, nivNP.nivel
  from vfp
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL` nivNP
  ON vfp.canal_alta_ds = nivNP.canal_ds  AND vfp.grupo_rappel_ds = nivNP.grupo_rappel  AND vfp.proyeccion_norm BETWEEN nivNP.BA_MIN  AND nivNP.BA_MAX;

END