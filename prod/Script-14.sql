-- DROP FUNCTION public.get_agent_and_team_counts(text, date, date, _text, text, _varchar);

CREATE OR REPLACE FUNCTION public.get_agent_and_team_counts(p_agent_id text, start_date date, end_date date, p_state_cd text[] DEFAULT NULL::text[], p_lead_type text DEFAULT 'all'::text, p_territory_ids character varying[] DEFAULT NULL::character varying[])
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Variables for aggregated metrics
    v_total_agents INT;
    v_total_territories INT;
    v_my_lead_count NUMERIC;
    v_team_numbers NUMERIC;
    v_sales_conversion_count INT;
    v_comeback_count INT;
    v_to_be_visited_count INT;
    v_do_not_knock_count INT;
    v_sales_conversion_avg NUMERIC;
    v_comeback_avg NUMERIC;
    v_to_be_visited_avg NUMERIC;
    v_do_not_knock_avg NUMERIC;
    agent_counts jsonb;
    team_counts_json jsonb;
BEGIN
    -- Normalizing input
    IF p_lead_type IS NOT NULL THEN
        p_lead_type := lower(p_lead_type::TEXT);
    END IF;

    IF p_state_cd IS NOT NULL AND array_length(p_state_cd, 1) = 0 THEN
        p_state_cd := NULL;
    END IF;

    IF p_territory_ids IS NOT NULL AND array_length(p_territory_ids, 1) = 0 THEN
        p_territory_ids := NULL;
    END IF;

    -- Fetch agent-level lead counts
    agent_counts := public.get_lead_counts_nds_2(p_agent_id, start_date, end_date, p_state_cd, p_lead_type, p_territory_ids);

    IF agent_counts->>'total_lead_count' IS NULL THEN
        agent_counts := agent_counts || jsonb_build_object('total_lead_count', 0);
    END IF;

    -- Optimized CTEs
    WITH CombinedFilters AS (
        SELECT 
            'zip_cd = ' || quote_literal(z.name) || ' AND isacc = false' AS combined_filter
        FROM salesforce.zip_code__c z
        JOIN "mapping"."Territory" t ON z.name = t.zip_cd
        WHERE t.expiration_date >= CURRENT_DATE
        AND t.isactive IS NOT FALSE
        AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids))
    ),
    DealerInfo AS (
        SELECT dealer_id
        FROM "mapping"."Teams"
        WHERE agent_id = p_agent_id
    ),
    AgentInfo AS (
        SELECT agent_id
        FROM "mapping"."Teams"
        WHERE dealer_id IN (SELECT dealer_id FROM DealerInfo)
    ),
    TerritoryInfo AS (
        SELECT 
            t2.territory_id,
            t.agent_id,
            t.dealer_id,
            t2.total_assigned_leads::NUMERIC AS total_assigned_leads
        FROM "mapping"."Teams" t
        JOIN "mapping"."Territory" t2 ON t.territory_id = t2.territory_id
        WHERE t.agent_id IN (SELECT agent_id FROM AgentInfo)
          AND t2.isactive IS NOT FALSE
          AND t2.expiration_date >= CURRENT_DATE
          AND (p_territory_ids IS NULL OR p_territory_ids = '{}' OR t2.territory_id = ANY(p_territory_ids))
    ),
    latest_dispositions AS (
        SELECT 
            ad.txt_audience_id,
            ad.txt_lead_disposition,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.txt_lead_disposition IS NOT NULL
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
    DispositionCounts AS (
        SELECT
            COUNT(DISTINCT tm.agent_id) AS total_agents,
            COUNT(DISTINCT t.territory_id) AS total_territories,
            COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') THEN 1 END) AS sales_conversion_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') THEN 1 END) AS comeback_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Follow up Appointment') THEN 1 END) AS to_be_visited_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree') THEN 1 END) AS do_not_knock_count
        FROM pgadmin."Prospect_partition" p
        LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        WHERE ad.rn = 1
          AND ST_Contains(tg.geom, ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326))
          AND t.expiration_date >= CURRENT_DATE
          AND t.isactive IS NOT FALSE
          AND EXISTS (SELECT 1 FROM CombinedFilters cf WHERE cf.combined_filter IS NOT NULL AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%')
          AND tm.agent_id IN (SELECT agent_id FROM "mapping"."Teams" WHERE dealer_id IN (SELECT dealer_id FROM "mapping"."Teams" WHERE agent_id = p_agent_id))
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
    -- Fetching aggregated results
    SELECT 
        total_agents,
        total_territories,
        my_lead_count,
        my_lead_count / NULLIF(total_agents, 0),
        sales_conversion_count,
        comeback_count,
        to_be_visited_count,
        do_not_knock_count
    INTO 
        v_total_agents, v_total_territories, v_my_lead_count, 
        v_team_numbers, v_sales_conversion_count, v_comeback_count, 
        v_to_be_visited_count, v_do_not_knock_count
    FROM DispositionCounts;

    -- Calculating averages
    v_sales_conversion_avg := COALESCE(v_sales_conversion_count, 0) / NULLIF(v_total_agents, 0);
    v_comeback_avg := COALESCE(v_comeback_count, 0) / NULLIF(v_total_agents, 0);
    v_to_be_visited_avg := COALESCE(v_to_be_visited_count, 0) / NULLIF(v_total_agents, 0);
    v_do_not_knock_avg := COALESCE(v_do_not_knock_count, 0) / NULLIF(v_total_agents, 0);

    -- Constructing team counts JSON
    team_counts_json := jsonb_build_object(
        'total_agents', COALESCE(v_total_agents, 0),
        'total_territories', COALESCE(v_total_territories, 0),
        'my_lead_count', COALESCE(v_my_lead_count, 0),
        'team_member_count', COALESCE(ROUND(v_team_numbers, 2), 0),
        'sales_conversion_count', COALESCE(v_sales_conversion_count, 0),
        'comeback_count', COALESCE(v_comeback_count, 0),
        'to_be_visited_count', COALESCE(v_to_be_visited_count, 0),
        'do_not_knock_count', COALESCE(v_do_not_knock_count, 0),
        'sales_conversion_avg', COALESCE(ROUND(v_sales_conversion_avg, 2), 0),
        'comeback_avg', COALESCE(ROUND(v_comeback_avg, 2), 0),
        'to_be_visited_avg', COALESCE(ROUND(v_to_be_visited_avg, 2), 0),
        'do_not_knock_avg', COALESCE(ROUND(v_do_not_knock_avg, 2), 0)
    );

    -- Returning combined JSON
    RETURN jsonb_build_object(
        'team_counts', team_counts_json,
        'agent_counts', agent_counts
    );
END;
$function$
;
