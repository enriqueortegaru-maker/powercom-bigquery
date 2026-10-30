BEGIN
  SELECT causa, COUNT(*) AS conceptos, SUM(rows_afectadas) AS filas, ROUND(SUM(importe),2) AS importe
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_warn_conceptos_sin_traductor`(DESDE)
  GROUP BY causa ORDER BY importe DESC;

  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_warn_conceptos_sin_traductor`(DESDE);
END