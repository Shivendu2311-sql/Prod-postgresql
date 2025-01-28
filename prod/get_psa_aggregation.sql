CREATE OR REPLACE FUNCTION public.get_psa_aggregation(p_psa character varying)
 RETURNS TABLE(total_workable_leads bigint, total_fiber_all bigint, total_sfu bigint, total_mdu bigint, total_new_wireless_opportunities bigint)
 LANGUAGE plpgsql
AS $function$
DECLARE
    psa_arr VARCHAR[] := string_to_array(p_psa, '|');
BEGIN
    RETURN QUERY SELECT COUNT(1) total_workable_leads,
       SUM(CASE WHEN hsia_qftn_speed_val >= 1000 AND hsia_qftn_speed_val <= 5000 THEN 1 ELSE 0 END) AS total_fiber_1g_5g,
       SUM(CASE WHEN (unit_designator_cd isnull or unit_designator_cd='') AND (unit_nbr isnull or unit_nbr='') THEN 1 ELSE 0 END) AS TOTAL_SFU,
       SUM(CASE WHEN (unit_designator_cd IS NOT NULL AND unit_designator_cd != '') OR (unit_nbr IS NOT NULL AND unit_nbr != '') THEN 1 ELSE 0 END) AS TOTAL_MDU,
       SUM(CASE WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 1 ELSE 0 END) AS total_new_wireless_opp
       FROM pgadmin."Prospect_partition" p
WHERE p.PSA IS NOT NULL
AND uv_variable_1 = 'Y'
AND isscrubbed = false
AND p.PSA = ANY(psa_arr);
--GROUP BY p.PSA;
END;
$function$
;
