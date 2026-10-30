BEGIN

-- ============================================================================
-- PROCEDURE B — pr_fl_calcula_decomisiones
-- Thin wrapper — mirrors KRT_PYME.pr_fl_calcula_decomisiones exactly.
-- NOTE: fl_ejecutaFlujoComisiones (line 11) CALL stays commented.
--       Activation into the live monthly flow is a separate, deliberate decision.
-- ============================================================================

  CALL `mm-commissions-reporting.KRT_MASIVO.pr_sb_creaTablaDecomisiones`(vid_mes);

END