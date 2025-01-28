-- DROP FUNCTION public.get_lead_counts_nds_2(text, date, date, _text, text, _varchar);

CREATE OR REPLACE FUNCTION public.get_lead_counts_nds_2(agent_id text, start_date date, end_date date, p_state_cd text[] DEFAULT NULL::text[], p_lead_type text DEFAULT 'all'::text, p_territory_ids character varying[] DEFAULT NULL::character varying[])
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    total_lead_count NUMERIC;
    sales_conversion_count INT;
    comeback_count INT;
    to_be_visited_count INT;
    do_not_knock_count INT;
BEGIN
    -- Normalize input values
    IF p_lead_type IS NOT NULL THEN
        p_lead_type := lower(p_lead_type::TEXT);
    END IF;

    IF p_state_cd IS NOT NULL AND array_length(p_state_cd, 1) = 0 THEN
        p_state_cd := NULL;
    END IF;

    IF p_territory_ids IS NOT NULL AND array_length(p_territory_ids, 1) = 0 THEN
        p_territory_ids := NULL;
    END IF;

    -- Core logic
    WITH DecodedFilters AS (
	    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
	      AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids))
	),
	
	CombinedFilters AS (
	    SELECT 
	        'zip_cd = ' || quote_literal(zip_cd) || ' AND isacc = false' AS combined_filter
	    FROM DecodedFilters
	),
 territory_coords AS (
        SELECT
            t.territory_id,
            (elem.elem ->> 'lng')::NUMERIC AS lng,
            (elem.elem ->> 'lat')::NUMERIC AS lat,
            elem.ordinality AS point_order
        FROM
            mapping."Territory" t,
            LATERAL jsonb_array_elements(t.geojson::jsonb) WITH ORDINALITY AS elem(elem, ordinality)
        WHERE
            t.expiration_date >= CURRENT_DATE
            AND t.isactive IS NOT FALSE
            AND (p_territory_ids IS NULL OR p_territory_ids = '{}' OR t.territory_id = ANY(p_territory_ids))
    ),
    territory_geometries AS (
        SELECT
            territory_id,
            ST_SetSRID(
                ST_MakePolygon(
                    ST_MakeLine(
                        ARRAY_AGG(
                            ST_MakePoint(lng, lat)
                            ORDER BY point_order
                        )
                    )
                ),
                4326
            ) AS geom
        FROM
            territory_coords
        GROUP BY
            territory_id
    ),
         latest_dispositions AS (
        SELECT
            ad.txt_audience_id,
            ad.txt_lead_disposition,
            ad.last_modified_date,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE --ad.last_modified_date is not null and 
        ad.txt_lead_disposition is not null AND ad.txt_agent_id = get_lead_counts_nds_2.agent_id

    ),
    matching_audience_ids AS (
        SELECT
            p.audience_id,
            ld.txt_audience_id,
            ld.txt_lead_disposition, ld.last_modified_date,
            t.territory_id
        FROM
            pgadmin."Prospect_partition" p
        JOIN
            mapping."Territory" t ON p.zip_cd = t.zip_cd AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))  
        JOIN
            territory_geometries tg ON tg.territory_id = t.territory_id
        LEFT JOIN
            latest_dispositions ld
            ON p.audience_id = ld.txt_audience_id AND ld.rn = 1 --and ld.txt_lead_disposition is not null -- Only the latest disposition
        JOIN
            mapping."Teams" tm ON tm.territory_id = t.territory_id
        WHERE 
          ST_Contains(
                tg.geom,
                ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
            ) and ld.txt_lead_disposition is not null
            and tm.agent_id = get_lead_counts_nds_2.agent_id        
            AND t.expiration_date >= CURRENT_DATE AND t.isactive IS NOT FALSE
            AND EXISTS (
            SELECT 1 
            FROM CombinedFilters cf 
            WHERE cf.combined_filter IS NOT NULL 
              -- Check if combined filter applies to zip codes dynamically.
              AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        )
            --AND CAST(ld.last_modified_date AS date) BETWEEN start_date AND end_date -- OR ld.last_modified_date IS NULL
           -- AND (p_lead_type = 'all' OR ld.txt_lead_disposition = p_lead_type) -- Filter by lead type
            AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids)) -- Filter by territory IDs
            AND (
        CASE 
            WHEN (
                ((unit_designator_cd IS NOT NULL AND unit_designator_cd != '') OR (unit_nbr IS NOT NULL AND unit_nbr != ''))
                AND (unit_designator_cd != 'UNDEFINED' AND unit_nbr != 'UNDEFINED')
            )
            THEN
                CASE
                    WHEN isfiber = true THEN 'fiber'
                    WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'wireless'
                    ELSE 'other'
                END
            ELSE
                CASE
                    WHEN isfiber = true THEN 'fiber'
                    WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'wireless'
                    ELSE 'other'
                END
        END = p_lead_type -- Compare against the parameter
        OR p_lead_type = 'all'
      
    )
 )
      SELECT
    COUNT(DISTINCT audience_id),
    COUNT(CASE 
        WHEN txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
        AND (last_modified_date IS NULL OR DATE(last_modified_date) BETWEEN start_date AND end_date) 
        THEN 1 END),
    COUNT(CASE 
        WHEN txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
        AND (last_modified_date IS NULL OR DATE(last_modified_date) BETWEEN start_date AND end_date) 
        THEN 1 END),
    COUNT(CASE 
        WHEN txt_lead_disposition IN ('Follow up Appointment') 
        AND (last_modified_date IS NULL OR DATE(last_modified_date) BETWEEN start_date AND end_date) 
        THEN 1 END),
    COUNT(CASE 
        WHEN txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) 
        AND (last_modified_date IS NULL OR DATE(last_modified_date) BETWEEN start_date AND end_date) 
        THEN 1 END)
    INTO
        total_lead_count,
        sales_conversion_count,
        comeback_count,
        to_be_visited_count,
        do_not_knock_count
    FROM
        matching_audience_ids;

    -- Handle null values for total_lead_count
    IF total_lead_count IS NULL THEN
        total_lead_count := 0;
    END IF;

    RETURN jsonb_build_object(
        'total_lead_count', total_lead_count,
        'sales_conversion', sales_conversion_count,
        'comeback', comeback_count,
        'to_be_visited', to_be_visited_count,
        'do_not_knock', do_not_knock_count
    );
END;
$function$
;
