BEGIN

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT
      * REPLACE(CAST(nivel AS string) AS nivel),
      ifnull(importe_nivel,
        0) + ifnull(bono_comercial,
        0) + ifnull(bono_calidad,
        0) total,
      NULL campana_id,
      '' nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS`
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
      nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;

END