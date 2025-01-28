SELECT json_agg(result)
FROM public.get_manager_dealer_data('0018b000025j7XSAAY', '2025-01-11', '2025-01-21')AS result;

"Adventure Dealer","zip_codes":"01007, 01031, 01033, 01034, 01035, 01039, 01057, 01066, 49037, 76065","zip_code_count":10,

SELECT json_agg(result)
FROM public.get_manager_dealer_data_3('0018b000025j7XSAAY', '2025-01-11', '2025-01-21')AS result;

 
SELECT json_agg(result)
FROM public.get_master_dealer_dashboard('0015c00002eT05NAAS', '2025-01-01', '2025-01-21')AS result;

SELECT json_agg(result)
FROM public.get_master_dealer_dashboard_3('0015c00002eT05NAAS', '2024-01-01', '2024-12-09')AS result;

select * from public.get_lead_counts_nds_2('005WG00000A4lQnYAJ','2024-12-31','2025-01-22','{}','all')

select * from public.get_lead_counts_nds_3('005WG00000A4lQnYAJ','2024-12-31','2025-01-22','{}','all')

select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ','2024-12-31','2025-01-22','{}','all')

{"team_counts": {"comeback_avg": 20.00, "total_agents": 10, "my_lead_count": 2287, "comeback_count": 206, "do_not_knock_avg": 39.00, "team_member_count": 228.00, 
"to_be_visited_avg": 18.00, "total_territories": 29, "do_not_knock_count": 397, "to_be_visited_count": 181, "sales_conversion_avg": 34.00, "sales_conversion_count": 348}, 
"agent_counts": {"comeback": 16, "do_not_knock": 33, "to_be_visited": 12, "sales_conversion": 29, "total_lead_count": 721}}


{"comeback": 77, "do_not_knock": 170, "to_be_visited": 39, "sales_conversion": 125, "total_lead_count": 721}

{"comeback": 96, "do_not_knock": 205, "to_be_visited": 63, "sales_conversion": 188, "total_lead_count": 721}

{"comeback": 96, "do_not_knock": 205, "to_be_visited": 55, "sales_conversion": 188, "total_lead_count": 721}

select * from public.get_lead_counts_nds_2_test('005WG00000A4lQnYAJ','2024-12-31','2025-01-22','{}','all')

-- DROP FUNCTION public.get_master_dealer_dashboard(text, date, date);

-- DROP FUNCTION public.get_master_dealer_dashboard_3(text, date, date);

-- DROP FUNCTION public.get_master_dealer_dashboard(text, date, date);

ALTER TABLE pgadmin."Prospect"
ADD COLUMN load_dt DATE,
ADD COLUMN rowno NUMERIC(18),
ADD COLUMN injection_date TIMESTAMP,
ADD COLUMN inserted_into_stage BOOLEAN,
ADD COLUMN update_type VARCHAR(1);


ALTER TABLE pgadmin."Prospect_partition"
ADD COLUMN rowno NUMERIC(18),
ADD COLUMN injection_date TIMESTAMP,
ADD COLUMN inserted_into_stage BOOLEAN,
ADD COLUMN update_type VARCHAR(1);


SELECT column_name
FROM information_schema.columns
WHERE table_name = 'Prospect_partition'
  AND table_schema = 'pgadmin'
  AND column_name = 'rowno';

SELECT inhrelid::regclass AS partition_name
FROM pg_inherits
WHERE inhparent = 'pgadmin."Prospect_partition"'::regclass;



-- DROP FUNCTION public.get_master_dealer_dashboard(text, date, date);

CREATE OR REPLACE FUNCTION public.get_master_dealer_dashboard_3(p_sfid text, p_start_date date, p_end_date date)
 RETURNS TABLE(result_date_range text, zip_code text, aggregated_zip_codes text, total_lead_count integer, sales_conversion_count integer, comeback_count integer, to_be_visited_count integer, do_not_knock_count integer, total_pending_disposition integer)
 LANGUAGE sql
AS $function$
WITH RECURSIVE account_hierarchy AS (
    -- Base case
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           CASE 
               WHEN parentid IS NULL THEN 1
               ELSE 2
           END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a1.sfid = zcc.last_assigned_dealer__c
        WHERE a1.sfid = p_sfid and ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))
 
    
    UNION ALL
    
    -- Recursive case
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a.sfid = zcc.last_assigned_dealer__c
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
    where ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))
),
dealer_hie AS (
    SELECT DISTINCT 
        ah.sfid, 
        ah.name, 
        ah.parentid,
        ah.email,
        ah.external_zip_code__c,
        ah.cid,
        ah.uid,
        ah.master_acct_id__c,
        ah.accountid__c,
        ah.dealeraccid__c,
        ah.isagent__c,
        CASE 
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
             AND (ah.master_acct_id__c IS NOT NULL AND ah.master_acct_id__c = ah.accountid__c AND ah.master_acct_id__c = ah.dealeraccid__c) 
             THEN 'Master Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NOT NULL 
             AND ah.accountid__c = ah.dealeraccid__c 
             AND ah.accountid__c != ah.master_acct_id__c
             THEN 'Manager Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NULL 
             AND ah.accountid__c = ah.dealeraccid__c
             THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
),
agent_metrics AS (
    SELECT 
        d.external_zip_code__c,
        tm.agent_id,
        COUNT(DISTINCT p.audience_id) AS total_lead_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') THEN 1 END) AS sales_conversion_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') THEN 1 END) AS comeback_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Follow up Appointment') THEN 1 END) AS to_be_visited_count,
        COUNT(CASE WHEN txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) THEN 1 END) AS do_not_knock_count,
        COUNT(CASE WHEN txt_lead_disposition NOT IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot', 'Decision Maker Not Home', 'No Answer',
            'Follow up Appointment', 'Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale'
        ) THEN 1 END) AS total_pending_disposition
    FROM dealer_hie d
    JOIN "mapping"."Teams" tm ON d.uid = tm.dealer_id 
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id
    --JOIN territory_geometries tg ON tm.territory_id = tg.territory_id
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE 
        (t.isactive IS NULL OR t.isactive = true)
        AND t.expiration_date >= CURRENT_DATE
        AND CAST(ad.last_modified_date AS date) BETWEEN p_start_date AND p_end_date
    GROUP BY d.external_zip_code__c, tm.agent_id
)
SELECT 
    TO_CHAR(p_start_date, 'YY/MM/DD') || ' - ' || TO_CHAR(p_end_date, 'YY/MM/DD') AS result_date_range,
    external_zip_code__c,
    STRING_AGG(DISTINCT external_zip_code__c, ', ') AS aggregated_zip_codes,
    SUM(total_lead_count) AS total_lead_count,
    SUM(sales_conversion_count) AS sales_conversion_count,
    SUM(comeback_count) AS comeback_count,
    SUM(to_be_visited_count) AS to_be_visited_count,
    SUM(do_not_knock_count) AS do_not_knock_count,
    SUM(total_pending_disposition) AS total_pending_disposition
FROM agent_metrics
GROUP BY result_date_range, external_zip_code__c;
$function$
;




WITH RECURSIVE account_hierarchy AS (
    -- Base case
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           CASE 
               WHEN parentid IS NULL THEN 1
               ELSE 2
           END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a1.sfid = zcc.last_assigned_dealer__c
        WHERE a1.sfid = '0015c00002eT05NAAS' and ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))
 
    
    UNION ALL
    
    -- Recursive case
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a.sfid = zcc.last_assigned_dealer__c
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
    where ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))
),
dealer_hie AS (
    SELECT DISTINCT 
        ah.sfid, 
        ah.name, 
        ah.parentid,
        ah.email,
        ah.external_zip_code__c,
        ah.cid,
        ah.uid,
        ah.master_acct_id__c,
        ah.accountid__c,
        ah.dealeraccid__c,
        ah.isagent__c,
        CASE 
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
             AND (ah.master_acct_id__c IS NOT NULL AND ah.master_acct_id__c = ah.accountid__c AND ah.master_acct_id__c = ah.dealeraccid__c) 
             THEN 'Master Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NOT NULL 
             AND ah.accountid__c = ah.dealeraccid__c 
             AND ah.accountid__c != ah.master_acct_id__c
             THEN 'Manager Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NULL 
             AND ah.accountid__c = ah.dealeraccid__c
             THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
),
    SELECT 
        d.external_zip_code__c,
        tm.agent_id,
        COUNT(DISTINCT p.audience_id) AS total_lead_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') THEN 1 END) AS sales_conversion_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') THEN 1 END) AS comeback_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Follow up Appointment') THEN 1 END) AS to_be_visited_count,
        COUNT(CASE WHEN txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) THEN 1 END) AS do_not_knock_count,
        COUNT(CASE WHEN txt_lead_disposition NOT IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot', 'Decision Maker Not Home', 'No Answer',
            'Follow up Appointment', 'Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale'
        ) THEN 1 END) AS total_pending_disposition
    FROM dealer_hie d
    JOIN "mapping"."Teams" tm ON d.uid = tm.dealer_id 
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id
    --JOIN territory_geometries tg ON tm.territory_id = tg.territory_id
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE 
        (t.isactive IS NULL OR t.isactive = true)
        AND t.expiration_date >= CURRENT_DATE
        AND CAST(ad.last_modified_date AS date) BETWEEN '2025-01-01' AND '2025-01-21'
    GROUP BY d.external_zip_code__c, tm.agent_id
    
    
    
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
            mapping."Territory" t ON p.zip_cd = t.zip_cd --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))  
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
    

-- DROP FUNCTION public.get_agent_and_team_counts_test(text, date, date, _text, text, _varchar);

CREATE OR REPLACE FUNCTION public.get_agent_and_team_counts_test(p_agent_id text, start_date date, end_date date, p_state_cd text[] DEFAULT NULL::text[], p_lead_type text DEFAULT 'all'::text, p_territory_ids character varying[] DEFAULT NULL::character varying[])
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Variables for aggregated metrics
    v_total_agents INT;
    v_total_territories INT;
    v_my_lead_count NUMERIC;
    v_team_numbers NUMERIC;

    -- Disposition counts and averages
    v_sales_conversion_count INT;
    v_comeback_count INT;
    v_to_be_visited_count INT;
    v_do_not_knock_count INT;
    v_sales_conversion_avg NUMERIC;
    v_comeback_avg NUMERIC;
    v_to_be_visited_avg NUMERIC;
    v_do_not_knock_avg NUMERIC;

    -- JSON objects for the output
    agent_counts jsonb;
    team_counts_json jsonb;
BEGIN
    
    IF p_lead_type IS NOT NULL THEN
        p_lead_type := lower(p_lead_type::TEXT);
    END IF;

    IF p_state_cd IS NOT NULL AND array_length(p_state_cd, 1) = 0 THEN
        p_state_cd := NULL;
    END IF;

    IF p_territory_ids IS NOT NULL AND array_length(p_territory_ids, 1) = 0 THEN
        p_territory_ids := NULL;
    END IF;

    -- Fetch agent-level lead counts using state_cd
    agent_counts := public.get_lead_counts_nds_2(
        p_agent_id,
        start_date,
        end_date,
        --COALESCE(p_state_cd, ARRAY[]::text[]) -- Handle optional p_state_cd
        CASE
    WHEN p_state_cd IS NULL OR p_state_cd =  '{}' OR array_length(p_state_cd, 1) = 0 OR array_position(p_state_cd, '') IS NOT NULL THEN NULL
    ELSE p_state_cd
END

    );

    -- Handle null values for total_lead_count
    IF agent_counts->>'total_lead_count' IS NULL THEN
        agent_counts := agent_counts || jsonb_build_object('total_lead_count', 0);
    END IF;

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

    -- Main CTEs with territory geometries and required aggregations
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
            t2.total_assigned_leads::NUMERIC AS total_assigned_leads,
            t2.isactive,
            t2.expiration_date
        FROM "mapping"."Teams" t
        JOIN "mapping"."Territory" t2 ON t.territory_id = t2.territory_id
        WHERE t.agent_id IN (SELECT agent_id FROM AgentInfo)
          AND t2.isactive IS NOT FALSE
          AND t2.expiration_date >= CURRENT_DATE
          AND (p_territory_ids IS NULL OR p_territory_ids = '{}'
                 OR t2.territory_id = ANY(p_territory_ids))
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
    latest_dispositions AS (
        SELECT
            ad.txt_audience_id,
            ad.last_modified_date,
            ad.txt_lead_disposition,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.last_modified_date IS NOT NULL
        UNION ALL
        SELECT
            ad.txt_audience_id,
            NULL AS last_modified_date,
            ad.txt_lead_disposition,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.last_modified_date IS NULL
    ),
    DispositionCounts AS (
        SELECT
            COUNT(DISTINCT tm.agent_id) AS total_agents,
            COUNT(DISTINCT t.territory_id) AS total_territories,
            COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') THEN 1 END) AS sales_conversion_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') THEN 1 END) AS comeback_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN ('Follow up Appointment') THEN 1 END) AS to_be_visited_count,
            COUNT(CASE WHEN ad.txt_lead_disposition IN (
                'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
                'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
                'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
                'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
                'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
                'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
            ) THEN 1 END) AS do_not_knock_count
        FROM
            pgadmin."Prospect_partition" p
        LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id AND ad.rn = 1
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))  
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        WHERE tm.agent_id IN (
            SELECT agent_id
            FROM "mapping"."Teams"
            WHERE dealer_id IN (
                SELECT dealer_id
                FROM "mapping"."Teams"
                WHERE agent_id = p_agent_id
            )
        )
        AND (p_territory_ids IS NULL OR p_territory_ids = '{}'
               OR t.territory_id = ANY(p_territory_ids))
        and t.expiration_date >= current_date
        and ST_Contains(
                    tg.geom,
                    ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
                )
        and t.isactive is not false  
        AND t.territory_id IN (
            SELECT territory_id
            FROM "mapping"."Territory"
            WHERE territory_id IN (
                SELECT t2.territory_id
                FROM TerritoryInfo t2
                JOIN territory_geometries tg ON tg.territory_id = t2.territory_id
                WHERE ST_Contains(
                    tg.geom,
                    ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
                )
            )
        )
 -- Include combined filters from CombinedFilters without adding an additional AND.
        AND EXISTS (
            SELECT 1 
            FROM CombinedFilters cf 
            WHERE cf.combined_filter IS NOT NULL 
              -- Check if combined filter applies to zip codes dynamically.
              AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        )
        AND CAST(ad.last_modified_date AS date) BETWEEN start_date AND end_date
        --AND ISSCRUBBED = false
    --AND UV_VARIABLE_1 = 'Y'
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
    -- Fetch the aggregated results
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

    -- Averages
    v_sales_conversion_avg := COALESCE(v_sales_conversion_count, 0) / NULLIF(v_total_agents, 0);
    v_comeback_avg := COALESCE(v_comeback_count, 0) / NULLIF(v_total_agents, 0);
    v_to_be_visited_avg := COALESCE(v_to_be_visited_count, 0) / NULLIF(v_total_agents, 0);
    v_do_not_knock_avg := COALESCE(v_do_not_knock_count, 0) / NULLIF(v_total_agents, 0);

    -- Team counts JSON
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

    -- Return combined JSON
    RETURN jsonb_build_object(
        'team_counts', team_counts_json,
        'agent_counts', agent_counts
    );
END;
$function$
;
