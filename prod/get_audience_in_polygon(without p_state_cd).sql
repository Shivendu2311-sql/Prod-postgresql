-- DROP FUNCTION public.get_audience_in_polygon(uuid, text, text, bool);

CREATE OR REPLACE FUNCTION public.get_audience_in_polygon(p_territory_id uuid, p_user_id text, p_account_id text, p_is_nbs_user boolean)
 RETURNS TABLE(audience_id text, lat numeric, lng numeric, full_name text, address text, txt_lead_disposition text, num_knocks integer, txt_notes text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_zip_cd TEXT;
    v_geojson TEXT;
    v_is_complete_zip_code BOOLEAN;
    v_polygon GEOMETRY;
    v_zip_cds TEXT[];
BEGIN
    -- Step 1: Retrieve Territory Data
    SELECT zip_cd, geojson, is_complete_zip_code
    INTO v_zip_cd, v_geojson, v_is_complete_zip_code
    FROM mapping."Territory"
    WHERE territory_id = p_territory_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Territory not found';
    END IF;

    -- Step 2: Parse GeoJSON to Geometry
    v_polygon := ST_SetSRID(ST_GeomFromGeoJSON(v_geojson::JSON), 4326);

    -- Step 3: Prepare ZIP Codes
    v_zip_cds := string_to_array(v_zip_cd, ' ');

    -- Step 4: Fetch Houses in ZIP Codes
    IF p_is_nbs_user THEN
        -- For NBS users
        RETURN QUERY
        WITH houses AS (
            SELECT
                sub_account_id AS audience_id,
                lat::NUMERIC,
                long::NUMERIC
            FROM pgadmin."NBSProspect"
            WHERE zip_cd = ANY (v_zip_cds)
        ),
        filtered_houses AS (
            SELECT *
            FROM houses
            WHERE v_is_complete_zip_code
               OR ST_Contains(v_polygon, ST_SetSRID(ST_MakePoint(houses.long, houses.lat), 4326))
        )
        -- Step 5: Retrieve Detailed Information
        SELECT
            p.business_name AS full_name,
            'false' AS ismdu,
            COALESCE(p.bus_loc_addr_ln_1_txt, '') || ' ' || COALESCE(p.bus_loc_addr_ln_2_txt, '') || ' ' || COALESCE(p.bus_loc_addr_ln_3_txt, '') || ' - ' || COALESCE(p.loc_addr_cty_nm, '') || ', ' || COALESCE(p.state_cd, '') || ' ' || COALESCE(p.zip_cd, '') AS address,
            ad.txt_lead_disposition,
            ad.num_knocks,
            ad.txt_notes,
            '' AS street_nbr,
            '' AS street_nm_pre_dir,
            '' AS street_nm,
            '' AS street_nm_sfx,
            '' AS street_nm_post_dir,
            '' AS unit_designator_cd,
            '' AS unit_nbr,
            p.loc_addr_cty_nm,
            p.state_cd,
            p.zip_cd,
            p.zip4_cd,
            p.lat::NUMERIC,
            p.long::NUMERIC,
            '' AS lang_desc,
            '' AS df_curr_internet,
            '' AS hsia_qftn_speed_val,
            '' AS hsia_csi_elig_ind,
            '' AS pstpd_wrls_subsrptn_sts_cd,
            '' AS dtv_subsrptn_sts_cd,
            p.notes,
            '' AS uv_variable_1,
            p.sub_account_id AS audience_id,
            '' AS clli_cd,
            '' AS dstrb_area_cd,
            '' AS dma_nm,
            '' AS psa,
            '' AS rdy_4sale_dt,
            p.lastmodifieddate,
            z.presently_assigned_dealer__c AS previously_assigned_dealer__c,
            p.assigned_date__c,
            p.end_date__c,
            '' AS glbl_lvng_unit_id,
            COALESCE(p.industry, '') AS industry,
            COALESCE(p.wireless_status, '') AS wireless_status,
            COALESCE(p.air_bb_suitability, '') AS air_bb_suitability,
            COALESCE(p.wireline_status, '') AS wireline_status,
            COALESCE(p.max_speed, '') AS max_speed,
            p.lit_date,
            COALESCE(p.sales_opportunity, '') AS sales_opportunity,
            COALESCE(p.job_score, 0) AS job_score,
            '' AS transport_type
        FROM filtered_houses fh
        JOIN pgadmin."NBSProspect" p ON p.sub_account_id = fh.audience_id
        INNER JOIN salesforce."nbs_zip_code__c" z ON p.zip_cd = z.name
        LEFT JOIN pgadmin."NBSAgentDisposition" ad ON p.sub_account_id = ad.txt_audience_id AND ad.txt_agent_id = p_user_id
        WHERE z.presently_assigned_dealer__c = p_account_id;
    ELSE
        -- For non-NBS users
        RETURN QUERY
        WITH houses AS (
            SELECT
                audience_id,
                uv_variable_4::NUMERIC AS lat,
                uv_variable_5::NUMERIC AS lng
            FROM pgadmin."Prospect_partition"
            WHERE zip_cd = ANY (v_zip_cds)
        ),
        filtered_houses AS (
            SELECT *
            FROM houses
            WHERE v_is_complete_zip_code
               OR ST_Contains(v_polygon, ST_SetSRID(ST_MakePoint(houses.lng, houses.lat), 4326))
        )
        -- Step 5: Retrieve Detailed Information
        SELECT
            p.full_nm AS full_name,
            p.ismdu,
            COALESCE(p.street_nbr, '') || ' ' || COALESCE(p.street_nm_pre_dir, '') || ' ' || COALESCE(p.street_nm, '') || ' ' || COALESCE(p.street_nm_sfx, '') || ' ' || COALESCE(p.street_nm_post_dir, '') || ' ' || COALESCE(p.unit_designator_cd, '') || ' ' || COALESCE(p.unit_nbr, '') || ' - ' || COALESCE(p.loc_addr_city_nm, '') || ', ' || COALESCE(p.state_cd, '') || ' ' || COALESCE(p.zip_cd, '') || '-' || COALESCE(p.zip4_cd, '') AS address,
            ad.txt_lead_disposition,
            ad.num_knocks,
            ad.txt_notes,
            p.street_nbr,
            p.street_nm_pre_dir,
            p.street_nm,
            p.street_nm_sfx,
            p.street_nm_post_dir,
            p.unit_designator_cd,
            p.unit_nbr,
            p.loc_addr_city_nm,
            p.state_cd,
            p.zip_cd,
            p.zip4_cd,
            p.uv_variable_4::NUMERIC AS lat,
            p.uv_variable_5::NUMERIC AS lng,
            p.lang_desc,
            p.df_curr_internet,
            ROUND(p.hsia_qftn_speed_val) AS hsia_qftn_speed_val,
            p.hsia_csi_elig_ind,
            CASE p.pstpd_wrls_subsrptn_sts_cd WHEN 'A' THEN 'Yes' ELSE 'No' END AS pstpd_wrls_subsrptn_sts_cd,
            CASE p.dtv_subsrptn_sts_cd WHEN 'A' THEN 'Yes' ELSE 'No' END AS dtv_subsrptn_sts_cd,
            p.notes,
            p.uv_variable_1,
            p.audience_id,
            p.clli_cd,
            p.dstrb_area_cd,
            p.dma_nm,
            p.psa,
            p.rdy_4sale_dt,
            p.last_modified_date__c,
            z.last_assigned_dealer__c AS last_assigned_dealer__c,
            p.assigned_date__c,
            p.end_date__c,
            p.glbl_lvng_unit_id,
            p.uv_variable_14,
            p.uv_variable_15,
            p.hyperlocal_ind,
            p.hyperlocal_offer
        FROM filtered_houses fh
        JOIN pgadmin."Prospect_partition" p ON p.audience_id = fh.audience_id
        INNER JOIN salesforce."zip_code__c" z ON p.zip_cd = z.name
        LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id AND ad.txt_agent_id = p_user_id
        WHERE p.uv_variable_1 = 'Y'
          AND z.last_assigned_dealer__c = p_account_id;
    END IF;

END;
$function$
;
