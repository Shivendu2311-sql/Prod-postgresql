--- prod

-- DROP FUNCTION public.get_icon_color_by_audience_id(varchar);

CREATE OR REPLACE FUNCTION public.get_icon_color_by_audience_id(p_audience_id character varying)
 RETURNS TABLE(audience_json_output json)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY 
    SELECT json_build_object(
        'AUD', json_agg(p.audience_id),
        'LAT', json_agg(p.uv_variable_4),
        'LON', json_agg(p.uv_variable_5),
        'ADD', json_agg(
            COALESCE(p.street_nbr, '') || ' ' || 
            COALESCE(p.street_nm_pre_dir, '') || ' ' || 
            COALESCE(p.street_nm, '') || ' ' || 
            COALESCE(p.street_nm_sfx, '') || ' ' || 
            COALESCE(p.street_nm_post_dir, '') || ' ' || 
            COALESCE(p.unit_designator_cd, '') || ' ' || 
            COALESCE(p.unit_nbr, '') || ' - ' || 
            COALESCE(p.loc_addr_city_nm, '') || ', ' || 
            COALESCE(p.state_cd, '') || ' ' || 
            COALESCE(p.zip_cd, '') || '-' || COALESCE(p.zip4_cd, '')
        ), 
        'NAME', json_agg(p.full_nm),
        'CURR_SPEED', json_agg(p.df_curr_internet),
        'MAX_SPEED', json_agg(ROUND(p.hsia_qftn_speed_val)),
        'CSI_ELI', json_agg(p.hsia_csi_elig_ind),
        'WIR_OPP', json_agg(CASE p.pstpd_wrls_subsrptn_sts_cd WHEN 'A' THEN 'Yes' ELSE 'No' END),
        'DNK', json_agg(p.uv_variable_1),
        'LAST_MDF_DATE', json_agg(p.last_modified_date),
        'BRD_ACT_DATE', json_agg(p.uv_variable_14),
        'WIFI_ACT_DATE', json_agg(p.uv_variable_15),
        'EXP_DATE', json_agg(z.end_date__c),
        'ICON', json_agg(m.icon_api)
    )
    FROM pgadmin."Prospect_partition" p 
    INNER JOIN salesforce."zip_code__c" z 
    ON p.zip_cd = z.name 
    INNER JOIN pgadmin."map_link_table" m 
    ON (
        CASE 
            WHEN ((p.unit_designator_cd IS NOT NULL AND p.unit_designator_cd != '') OR (p.unit_nbr IS NOT NULL AND p.unit_nbr != '')) 
            AND (p.unit_designator_cd != 'UNDEFINED' AND p.unit_nbr != 'UNDEFINED') THEN 
                CASE 
                    WHEN (NULLIF(p.uv_variable_18, '') IS NOT NULL AND NULLIF(p.uv_variable_18, '')::timestamp != TO_TIMESTAMP('1900-01-01', 'YYYY-MM-DD')) 
                    AND NULLIF(p.uv_variable_18, '')::timestamp <= (CURRENT_DATE - INTERVAL '30 days') THEN 'mdu_new_fiber'
                    WHEN (NULLIF(p.uv_variable_18, '') IS NOT NULL AND NULLIF(p.uv_variable_18, '')::timestamp != TO_TIMESTAMP('1900-01-01', 'YYYY-MM-DD')) 
                    AND NULLIF(p.uv_variable_18, '')::timestamp > CURRENT_DATE THEN 'mdu_fiber'
                    WHEN p.pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'mdu_wireless'
                    ELSE 'mdu'
                END
            ELSE
                CASE
                    WHEN (NULLIF(p.uv_variable_18, '') IS NOT NULL AND NULLIF(p.uv_variable_18, '')::timestamp != TO_TIMESTAMP('1900-01-01', 'YYYY-MM-DD')) 
                    AND NULLIF(p.uv_variable_18, '')::timestamp <= (CURRENT_DATE - INTERVAL '30 days') THEN 'sfu_new_fiber'
                    WHEN (NULLIF(p.uv_variable_18, '') IS NOT NULL AND NULLIF(p.uv_variable_18, '')::timestamp != TO_TIMESTAMP('1900-01-01', 'YYYY-MM-DD')) 
                    AND NULLIF(p.uv_variable_18, '')::timestamp > CURRENT_DATE THEN 'sfu_fiber'
                    WHEN p.pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'sfu_wireless'
                    ELSE 'sfu'
                END
        END
    ) = m.identifier
    WHERE p.audience_id = p_audience_id
    AND p.isscrubbed = false
    AND p.uv_variable_1 = 'Y';
END;
$function$
;
