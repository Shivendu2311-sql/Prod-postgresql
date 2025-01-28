-- DROP FUNCTION public.get_psa_color(varchar, varchar);

CREATE OR REPLACE FUNCTION public.get_psa_color(p_psa character varying, p_color character varying)
 RETURNS TABLE(psa_json_output json)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT json_build_object('AUD', json_agg(audience_id),'LAT', json_agg(uv_variable_4),'LON', json_agg(uv_variable_5),'ADD', json_agg(COALESCE(street_nbr, '') || ' ' || COALESCE(street_nm_pre_dir, '') || ' ' || COALESCE(street_nm, '') || ' ' || 
COALESCE(street_nm_sfx, '') || ' ' || COALESCE(street_nm_post_dir, '') || ' ' || COALESCE(unit_designator_cd, '') || ' ' || COALESCE(unit_nbr, '') || ' - ' || COALESCE(loc_addr_city_nm, '') || ', ' || COALESCE(state_cd, '') || ' ' || 
COALESCE(zip_cd, '') || '-' || COALESCE(zip4_cd, '')), 'NAME', json_agg(full_nm),'CURR_SPEED', json_agg(df_curr_internet),'MAX_SPEED', json_agg(ROUND(hsia_qftn_speed_val)),'CSI_ELI', json_agg(hsia_csi_elig_ind),'WIR_OPP', 
json_agg(CASE pstpd_wrls_subsrptn_sts_cd WHEN 'A' THEN 'Yes' ELSE 'No' END ),'DNK', json_agg(uv_variable_1), 'LAST_MDF_DATE', json_agg(last_modified_date__c), 'EXP_DATE', json_agg(end_date__c), 'PSA', json_agg(u.u_psa), 
'COLOR', json_agg(u.u_color)) 
FROM pgadmin."Prospect_partition" p INNER JOIN unnest(string_to_array(p_psa, ' '), string_to_array(p_color, ' ')) as u(u_psa, u_color) 
ON p.psa = u.u_psa INNER JOIN salesforce."zip_code__c" z ON p.zip_cd = z.name LIMIT 100;
END; 
$function$
;
