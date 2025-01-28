-- DROP FUNCTION public.get_audience_in_polygon(text, text, bool, text, _text);

CREATE OR REPLACE FUNCTION public.get_audience_in_polygon(account_id text, user_id text, nbs_user boolean, p_territory_id text, p_state_cd text[])
 RETURNS TABLE(full_nm text, ismdu boolean, address text, txt_lead_disposition text, num_knocks integer, txt_notes text, street_nbr text, street_nm_pre_dir text, street_nm text, street_nm_sfx text, street_nm_post_dir text, unit_designator_cd text, unit_nbr text, loc_addr_cty_nm text, state_cd text, zip_cd text, zip4_cd text, lat numeric, long numeric, lang_desc text, df_curr_internet text, hsia_qftn_speed_val text, hsia_csi_elig_ind text, pstpd_wrls_subsrptn_sts_cd text, dtv_subsrptn_sts_cd text, notes text, uv_variable_1 text, audience_id text, clli_cd text, dstrb_area_cd text, dma_nm text, psa text, rdy_4sale_dt text, lastmodifieddate timestamp without time zone, previously_assigned_dealer__c text, assigned_date__c date, end_date__c date, glbl_lvng_unit_id text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    polygon_coordinates numeric[][];  -- Array of numeric arrays
    zip_cd_array text[];
    audience_ids_inside_polygon text[];
BEGIN
    -- Get the geojson from the Territory table using p_territory_id
    SELECT array_agg(ARRAY[(geojson->>'lat')::numeric, (geojson->>'lng')::numeric]) 
    INTO polygon_coordinates
    FROM mapping."Territory"
    WHERE territory_id = p_territory_id;

    -- Fetch zip codes from the Territory table using p_territory_id
    SELECT array_agg(t.zip_cd::text)  -- Ensure casting to text
    INTO zip_cd_array
    FROM mapping."Territory" t
    WHERE t.territory_id = p_territory_id;

    -- Fetch houses based on zip_cd, nbs_user, and state_cd
    IF nbs_user THEN
        SELECT array_agg(p.sub_account_id::text)  -- Cast to text
        INTO audience_ids_inside_polygon
        FROM pgadmin."NBSProspect" p
        WHERE EXISTS (
            SELECT 1
            FROM unnest(zip_cd_array) AS zc
            WHERE p.zip_cd = zc
        )
        AND p.state_cd = ANY(p_state_cd);  -- Filter by state_cd
    ELSE
        SELECT array_agg(p.audience_id::text)  -- Cast to text
        INTO audience_ids_inside_polygon
        FROM pgadmin."Prospect_partition" p
        WHERE NOT p.isscrubbed
        AND EXISTS (
            SELECT 1
            FROM unnest(zip_cd_array) AS zc
            WHERE p.zip_cd = zc
        )
        AND p.state_cd = ANY(p_state_cd);  -- Filter by state_cd
    END IF;

    -- Fetch relevant data using audience_ids_inside_polygon
    RETURN QUERY
    SELECT
        (p.contact_first_1 || ' ' || p.contact_last_1)::text AS full_nm,
        FALSE AS ismdu,
        (COALESCE(p.bus_loc_addr_ln_1_txt, '') || ' ' || COALESCE(p.bus_loc_addr_ln_2_txt, '') || ' ' || COALESCE(p.bus_loc_addr_ln_3_txt, '') || ' - ' || COALESCE(p.loc_addr_cty_nm, '') || ', ' || COALESCE(p.state_cd, '') || ' ' || COALESCE(p.zip_cd, '') || '-' || COALESCE(p.zip4_cd, ''))::text AS address,
        ad.txt_lead_disposition::text,
        ad.num_knocks,
        ad.txt_notes::text,
        NULL::text AS street_nbr,
        NULL::text AS street_nm_pre_dir,
        NULL::text AS street_nm,
        NULL::text AS street_nm_sfx,
        NULL::text AS street_nm_post_dir,
        NULL::text AS unit_designator_cd,
        NULL::text AS unit_nbr,
        p.loc_addr_cty_nm::text,  -- Cast to text
        p.state_cd::text,  -- Cast to text
        p.zip_cd::text,  -- Cast to text
        p.zip4_cd::text,  -- Cast to text
        p.lat::numeric,   -- Cast to numeric
        p.long::numeric,  -- Cast to numeric
        NULL::text AS lang_desc,
        NULL::text AS df_curr_internet,
        NULL::text AS hsia_qftn_speed_val,
        NULL::text AS hsia_csi_elig_ind,
        NULL::text AS pstpd_wrls_subsrptn_sts_cd,
        NULL::text AS dtv_subsrptn_sts_cd,
        p.notes::text,
        NULL::text AS uv_variable_1,
        p.sub_account_id::text AS audience_id,
        NULL::text AS clli_cd,
        NULL::text AS dstrb_area_cd,
        NULL::text AS dma_nm,
        NULL::text AS psa,
        NULL::text AS rdy_4sale_dt,
        z.lastmodifieddate,
        z.presently_assigned_dealer__c::text AS previously_assigned_dealer__c,
        z.assigned_date__c,
        z.end_date__c,
        NULL::text AS glbl_lvng_unit_id
    FROM
        pgadmin."NBSProspect" p
    INNER JOIN
        salesforce."nbs_zip_code__c" z ON p.zip_cd = z.name
    LEFT JOIN
        pgadmin."NBSAgentDisposition" ad ON p.sub_account_id = ad.txt_audience_id AND ad.txt_agent_id = user_id
    WHERE
        p.sub_account_id = ANY(audience_ids_inside_polygon)
        AND z.presently_assigned_dealer__c = account_id;
END;
$function$
;
