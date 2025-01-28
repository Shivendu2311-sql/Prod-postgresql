-- DROP FUNCTION public.get_sub_acc_aggregation(varchar);

CREATE OR REPLACE FUNCTION public.get_sub_acc_aggregation(p_aloc character varying)
 RETURNS TABLE(total_assigned_leads text, total_fiber_all text, total_bb text, total_25m_plus text, total_new_wireless_opportunities text, total_sfu text, total_mdu text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    aloc_arr VARCHAR[] := string_to_array(p_aloc, '|');
BEGIN
    RETURN QUERY SELECT 
       CAST(COUNT(*) AS TEXT) AS total_assigned_leads,
       '0' AS total_fiber_1g_5g,
       '0' AS total_bb,
       '0' AS total_25m_plus,
       '0' AS total_new_wireless_opp,
       '0' AS TOTAL_SFU,
       '0' AS TOTAL_MDU
       FROM pgadmin."NBSProspect" p
WHERE 
-- uv_variable_1 = 'Y'
-- AND isscrubbed = false
-- AND
p.sub_account_id = ANY(aloc_arr);
END;
$function$
;
