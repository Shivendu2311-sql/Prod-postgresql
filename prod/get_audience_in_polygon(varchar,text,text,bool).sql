-- DROP FUNCTION public.get_audience_in_polygon(varchar, text, text, bool);

CREATE OR REPLACE FUNCTION public.get_audience_in_polygon(p_territory_id character varying, p_user_id text, p_account_id text, p_is_nbs_user boolean)
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

    -- Output the retrieved GeoJSON
    RAISE NOTICE 'v_geojson: %', v_geojson;

    -- Check if v_geojson is NULL or empty
    IF v_geojson IS NULL OR trim(v_geojson) = '' THEN
        RAISE EXCEPTION 'GeoJSON data is NULL or empty for territory_id %', p_territory_id;
    END IF;

    -- Check if v_geojson is an array (starts with '[')
    IF left(trim(v_geojson), 1) = '[' THEN
        -- Transform the array of points into a GeoJSON Polygon
        v_geojson := json_build_object(
            'type', 'Polygon',
            'coordinates', json_build_array(
                (SELECT json_agg(json_build_array(
                    (point.point ->> 'lng')::NUMERIC,
                    (point.point ->> 'lat')::NUMERIC
                ) ORDER BY point.ordinality)
                FROM jsonb_array_elements(v_geojson::jsonb) WITH ORDINALITY AS point(point, ordinality))
            )
        )::text;

        -- Output the transformed GeoJSON
        RAISE NOTICE 'Transformed v_geojson: %', v_geojson;
    END IF;

    -- Now parse the transformed GeoJSON
    v_polygon := ST_SetSRID(ST_GeomFromGeoJSON(v_geojson), 4326);

    -- Step 3: Prepare ZIP Codes
    v_zip_cds := string_to_array(v_zip_cd, '|');

    -- Output the ZIP codes array for debugging (optional)
    RAISE NOTICE 'v_zip_cds: %', array_to_string(v_zip_cds, ',');

    -- Step 4: Fetch Houses in ZIP Codes
    IF p_is_nbs_user THEN
        -- For NBS users
        RETURN QUERY
        WITH houses AS (
            SELECT
                p.sub_account_id AS audience_id,
                p.lat::NUMERIC,
                p.long::NUMERIC
            FROM pgadmin."NBSProspect" p
            WHERE p.zip_cd = ANY (v_zip_cds)
        ),
        filtered_houses AS (
            SELECT *
            FROM houses h
            WHERE v_is_complete_zip_code
               OR ST_Contains(v_polygon, ST_SetSRID(ST_MakePoint(h.long, h.lat), 4326))
        )
        -- Step 5: Retrieve Detailed Information
        SELECT
            fh.audience_id::TEXT,
            fh.lat,
            fh.long AS lng
            -- Add other columns as needed
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
                p.audience_id,
                p.uv_variable_4::NUMERIC AS lat,
                p.uv_variable_5::NUMERIC AS lng
            FROM pgadmin."Prospect_partition" p
            WHERE p.zip_cd = ANY (v_zip_cds)
        ),
        filtered_houses AS (
            SELECT *
            FROM houses h
            WHERE v_is_complete_zip_code
               OR ST_Contains(v_polygon, ST_SetSRID(ST_MakePoint(h.lng, h.lat), 4326))
        )
        -- Step 5: Retrieve Detailed Information
        SELECT
            fh.audience_id::TEXT,
            fh.lat,
            fh.lng,
              p.full_nm::TEXT AS full_name,
            (COALESCE(p.street_nbr, '') || ' ' || COALESCE(p.street_nm_pre_dir, '') || ' ' || COALESCE(p.street_nm, '') || ' ' || COALESCE(p.street_nm_sfx, '') || ' ' || COALESCE(p.street_nm_post_dir, '') || ' ' || COALESCE(p.unit_designator_cd, '') || ' ' || COALESCE(p.unit_nbr, '') || ' - ' || COALESCE(p.loc_addr_city_nm, '') || ', ' || COALESCE(p.state_cd, '') || ' ' || COALESCE(p.zip_cd, '') || '-' || COALESCE(p.zip4_cd, ''))::TEXT AS address,
            ad.txt_lead_disposition::TEXT,
            ad.num_knocks::INTEGER,
            ad.txt_notes::TEXT
            --Cast other columns as needed
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
