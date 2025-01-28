-- DROP FUNCTION public.get_leads_for_territory(varchar, varchar, bool, varchar);

CREATE OR REPLACE FUNCTION public.get_leads_for_territory(p_user_id character varying, p_account_id character varying, p_is_nbs boolean, p_territory_id character varying)
 RETURNS TABLE(full_nm text, ismdu boolean, address text, txt_lead_disposition text, num_knocks integer, txt_notes text, street_nbr text, street_nm_pre_dir text, street_nm text, street_nm_sfx text, street_nm_post_dir text, unit_designator_cd text, unit_nbr text, loc_addr_city_nm text, state_cd text, zip_cd text, zip4_cd text, lat numeric, long numeric, lang_desc text, df_curr_internet text, hsia_qftn_speed_val numeric, hsia_csi_elig_ind text, pstpd_wrls_subsrptn_sts_cd text, dtv_subsrptn_sts_cd text, notes text, uv_variable_1 text, audience_id text, clli_cd text, dstrb_area_cd text, dma_nm text, psa text, uv_variable_18 text, last_modified_date timestamp without time zone, last_assigned_dealer text, assigned_date text, end_date text, glbl_lvng_unit_id text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_is_nbs THEN
        RETURN QUERY 
        SELECT
            p.contact_first_1 || ' ' || p.contact_last_1 AS full_nm,
            false AS ismdu,
            COALESCE(p.bus_loc_addr_ln_1_txt, '') || ' ' || 
            COALESCE(p.bus_loc_addr_ln_2_txt, '') || ' ' || 
            COALESCE(p.bus_loc_addr_ln_3_txt, '') || ' - ' || 
            COALESCE(p.loc_addr_cty_nm, '') || ', ' || 
            COALESCE(p.state_cd, '') || ' ' || 
            COALESCE(p.zip_cd, '') || '-' || 
            COALESCE(p.zip4_cd, '') AS address,
            ad.txt_lead_disposition::text AS txt_lead_disposition,  -- Cast to text
            ad.num_knocks::integer AS num_knocks,  -- Ensure it's integer
            ad.txt_notes::text AS txt_notes,  -- Cast to text (Column 6)
            ''::text AS street_nbr,  -- Cast to text
            ''::text AS street_nm_pre_dir,  -- Cast to text
            ''::text AS street_nm,  -- Cast to text
            ''::text AS street_nm_sfx,  -- Cast to text
            ''::text AS street_nm_post_dir,  -- Cast to text
            ''::text AS unit_designator_cd,  -- Cast to text
            ''::text AS unit_nbr,  -- Cast to text
            p.loc_addr_cty_nm::text AS loc_addr_city_nm,  -- Cast to text
            p.state_cd::text AS state_cd,  -- Cast to text
            p.zip_cd::text AS zip_cd,  -- Cast to text
            p.zip4_cd::text AS zip4_cd,  -- Cast to text
            p.lat::numeric AS lat,  -- Ensure it's numeric
            p.long::numeric AS long,  -- Ensure it's numeric
            ''::text AS lang_desc,  -- Cast to text
            ''::text AS df_curr_internet,  -- Cast to text
            NULL::numeric AS hsia_qftn_speed_val,  -- Use NULL instead of an empty string
            ''::text AS hsia_csi_elig_ind,  -- Cast to text
            ''::text AS pstpd_wrls_subsrptn_sts_cd,  -- Cast to text
            ''::text AS dtv_subsrptn_sts_cd,  -- Cast to text
            p.notes::text AS notes,  -- Cast to text
            ''::text AS uv_variable_1,  -- Cast to text
            p.sub_account_id::text AS audience_id,  -- Cast to text
            ''::text AS clli_cd,  -- Cast to text
            ''::text AS dstrb_area_cd,  -- Cast to text
            ''::text AS dma_nm,  -- Cast to text
            ''::text AS psa,  -- Cast to text
            ''::text AS uv_variable_18,  -- Updated field, cast to text
            z.lastmodifieddate AS last_modified_date,  -- Ensure it's timestamp
            z.presently_assigned_dealer__c::text AS last_assigned_dealer,  -- Cast to text
            z.assigned_date__c::text AS assigned_date,  -- Cast to text
            z.end_date__c::text AS end_date,  -- Cast to text
            ''::text AS glbl_lvng_unit_id  -- Cast to text
        FROM
            pgadmin."NBSProspect" p
        INNER JOIN 
            salesforce."nbs_zip_code__c" z ON p.zip_cd = z.name
        LEFT OUTER JOIN 
            pgadmin."NBSAgentDisposition" ad ON p.sub_account_id = ad.txt_audience_id 
                                              AND ad.txt_agent_id = p_user_id
        WHERE
            p.sub_account_id IN (
                SELECT sub_account_id
                FROM mapping."Teams" t
                WHERE t.territory_id = p_territory_id AND t.agent_id = p_user_id
            )
            AND z.presently_assigned_dealer__c = p_account_id;
    ELSE
        RETURN QUERY 
        SELECT
            p.contact_first_1 || ' ' || p.contact_last_1 AS full_nm,
            p.ismdu::boolean AS ismdu,  -- Ensure it's boolean
            COALESCE(p.street_nbr, '') || ' ' || 
            COALESCE(p.street_nm_pre_dir, '') || ' ' || 
            COALESCE(p.street_nm, '') || ' ' || 
            COALESCE(p.street_nm_sfx, '') || ' ' || 
            COALESCE(p.street_nm_post_dir, '') || ' ' || 
            COALESCE(p.unit_designator_cd, '') || ' ' || 
            COALESCE(p.unit_nbr, '') || ' - ' || 
            COALESCE(p.loc_addr_city_nm, '') || ', ' || 
            COALESCE(p.state_cd, '') || ' ' || 
            COALESCE(p.zip_cd, '') || '-' || 
            COALESCE(p.zip4_cd, '') AS address,
            ad.txt_lead_disposition::text AS txt_lead_disposition,  -- Cast to text
            ad.num_knocks::integer AS num_knocks,  -- Ensure it's integer
            ad.txt_notes::text AS txt_notes,  -- Cast to text (Column 6)
            p.street_nbr::text AS street_nbr,  -- Cast to text
            p.street_nm_pre_dir::text AS street_nm_pre_dir,  -- Cast to text
            p.street_nm::text AS street_nm,  -- Cast to text
            p.street_nm_sfx::text AS street_nm_sfx,  -- Cast to text
            p.street_nm_post_dir::text AS street_nm_post_dir,  -- Cast to text
            p.unit_designator_cd::text AS unit_designator_cd,  -- Cast to text
            p.unit_nbr::text AS unit_nbr,  -- Cast to text
            p.loc_addr_city_nm::text AS loc_addr_city_nm,  -- Cast to text
            p.state_cd::text AS state_cd,  -- Cast to text
            p.zip_cd::text AS zip_cd,  -- Cast to text
            p.zip4_cd::text AS zip4_cd,  -- Cast to text
            p.uv_variable_4::numeric AS lat,  -- Cast to numeric
            p.uv_variable_5::numeric AS long,  -- Cast to numeric
            p.lang_desc::text AS lang_desc,  -- Cast to text
            p.df_curr_internet::text AS df_curr_internet,  -- Cast to text
            ROUND(p.hsia_qftn_speed_val)::numeric AS hsia_qftn_speed_val,  -- Cast to numeric
            p.hsia_csi_elig_ind::text AS hsia_csi_elig_ind,  -- Cast to text
            CASE p.pstpd_wrls_subsrptn_sts_cd 
                WHEN 'A' THEN 'Yes' 
                ELSE 'No' 
            END::text AS pstpd_wrls_subsrptn_sts_cd,  -- Cast to text
            CASE p.dtv_subsrptn_sts_cd 
                WHEN 'A' THEN 'Yes' 
                ELSE 'No' 
            END::text AS dtv_subsrptn_sts_cd,  -- Cast to text
            p.notes::text AS notes,  -- Cast to text
            p.uv_variable_1::text AS uv_variable_1,  -- Cast to text
            p.audience_id::text AS audience_id,  -- Cast to text
            p.clli_cd::text AS clli_cd,  -- Cast to text
            p.dstrb_area_cd::text AS dstrb_area_cd,  -- Cast to text
            p.dma_nm::text AS dma_nm,  -- Cast to text
            p.psa::text AS psa,  -- Cast to text
            p.uv_variable_18::text AS uv_variable_18,  -- updated field, cast to text
            p.last_modified_date__c AS last_modified_date,  -- Ensure it's timestamp
            z.last_assigned_dealer__c::text AS last_assigned_dealer,  -- Cast to text
            z.assigned_date__c::text AS assigned_date,  -- Cast to text
            z.end_date__c::text AS end_date,  -- Cast to text
            p.glbl_lvng_unit_id::text AS glbl_lvng_unit_id  -- Cast to text
        FROM
            pgadmin."Prospect_partition" p
        INNER JOIN 
            salesforce."zip_code__c" z ON p.zip_cd = z.name
        LEFT OUTER JOIN 
            pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id 
                                              AND ad.txt_agent_id = p_user_id
        WHERE
            p.uv_variable_1 = 'Y'
            AND p.audience_id IN (
                SELECT audience_id
                FROM mapping."Teams" t
                WHERE t.territory_id = p_territory_id AND t.agent_id = p_user_id
            )
            AND z.last_assigned_dealer__c = p_account_id;
    END IF;
END;
$function$
;
