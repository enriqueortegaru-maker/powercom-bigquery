BEGIN

    ---- OUT_RESUMEN
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.OUT_RESUMEN_PY` AS

    SELECT
      marca_ds,
      nombre_distribuidor,
      canal,
      subcanal,
      agente,
      idFijo,
      antiguedad,
      dni_cif,
      marca_cartera,
      NULL Campana_id,
      '' NombreCampana,
      Segmento,
      MARCO_RETRIBUTIVO,
      SUM(importe) importe,
      nivel,
      SUM(importe_nivel) importe_nivel,
      SUM(bono_comercial) bono_comercial,
      SUM(bono_calidad) bono_calidad,
      SUM(ifnull(importe_nivel,
          0) + ifnull(bono_comercial,
          0) + ifnull(bono_calidad,
          0)) total
    FROM
      `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_CARTERA_TMP_5_V2`
    GROUP BY
      marca_ds,
      nombre_distribuidor,
      canal,
      subcanal,
      agente,
      idFijo,
      antiguedad,
      dni_cif,
      marca_cartera,
      Segmento,
      MARCO_RETRIBUTIVO,
      nivel
    UNION ALL
    SELECT
      marca_ds,
      nombre_distribuidor,
      canal,
      subcanal,
      agente,
      idFijo,
      antiguedad,
      dni_cif,
      marca_cartera,
      Campana_id,
      nombre_campana,
      Segmento,
      MARCO_RETRIBUTIVO,
      SUM(importe) importe,
      0,
      SUM(importe_nivel) importe_nivel,
      0 bono_comercial,
      0 bono_calidad,
      SUM(ifnull(importe_nivel,
          0)) total
    FROM
      `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_CARTERA_TMP_9_V2`
    GROUP BY
      marca_ds,
      nombre_distribuidor,
      canal,
      subcanal,
      agente,
      idFijo,
      antiguedad,
      dni_cif,
      marca_cartera,
      Segmento,
      MARCO_RETRIBUTIVO,
      Campana_id,
      nombre_campana;


    ---- OUT_DETALLE

   CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.OUT_DETALLE_PY` AS

    SELECT
      * REPLACE(CAST(nivel AS string) AS nivel),
      ifnull(importe_nivel,
        0) + ifnull(bono_comercial,
        0) + ifnull(bono_calidad,
        0) total,
      NULL campana_id,
      '' nombre_campana
    FROM
      `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_CARTERA_TMP_5_V2`
    UNION ALL
    SELECT
      * EXCEPT(campana_id,
        nombre_campana,
        importe,
        importe_nivel,
        nivel_tvt_ups_virgin),
      importe,
      NULL,
      importe_nivel,
      0,
      0,
      ifnull(importe_nivel,
        0) total,
      campana_id,
      nombre_campana
    FROM
      `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_CARTERA_TMP_9_V2`;


    ---- OUT_DECOMISIONES
    CREATE OR REPLACE TABLE    
      `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES_PY` AS
    SELECT * 
    FROM
      `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_DECOMISIONAMIENTO_CARTERA`;

  END