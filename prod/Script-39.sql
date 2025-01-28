 WITH DecodedFilters AS (
	    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
	),
	
	CombinedFilters AS (
	    SELECT 
	        'zip_cd = ' || quote_literal(zip_cd) || ' AND isacc = false' AS combined_filter
	    FROM DecodedFilters
	),
    DealerInfo AS(
        SELECT dealer_id
        FROM "mapping"."Teams"
        WHERE agent_id = '005WG00000A4lQnYAJ'
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
            ad.txt_lead_disposition,
            ad.last_modified_date,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.txt_lead_disposition is not null 
          --and cast(ad.last_modified_date as date) BETWEEN start_date AND end_date 
		

    )
    
    SELECT
    COUNT(DISTINCT tm.agent_id) AS total_agents,
    COUNT(DISTINCT t.territory_id) AS total_territories,
    COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count,
    COUNT(CASE 
    WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
         AND (cast(ad.last_modified_date as date) BETWEEN '2025-01-16' AND '2025-01-23') 
    THEN  p.audience_id 
END) AS sales_conversion_count,

COUNT(CASE 
    WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
         AND (cast(ad.last_modified_date as date) BETWEEN '2025-01-16' AND '2025-01-23') 
    THEN  p.audience_id 
END) AS comeback_count,

COUNT(CASE 
    WHEN ad.txt_lead_disposition IN ('Follow up Appointment') 
         AND (cast(ad.last_modified_date as date) BETWEEN '2025-01-16' AND '2025-01-23') 
    THEN  p.audience_id 
END) AS to_be_visited_count,

COUNT(CASE 
    WHEN ad.txt_lead_disposition IN (
        'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
        'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
        'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
        'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
        'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
        'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
    ) 
         AND (cast(ad.last_modified_date as date) BETWEEN '2025-01-' AND '2025-01-23')  
   THEN p.audience_id 
END) AS do_not_knock_count
   

FROM
            pgadmin."Prospect_partition" p
        LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id  AND ad.rn = 1
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd  
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        JOIN CombinedFilters cf ON (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        WHERE ad.txt_lead_disposition is not null --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))
         and 
         ST_Contains(
                    tg.geom,
                    ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
                ) and t.expiration_date >= current_date and t.isactive is not false 
    
        and tm.agent_id IN (
            SELECT agent_id
            FROM "mapping"."Teams"
            WHERE dealer_id IN (
                SELECT dealer_id
                FROM "mapping"."Teams"
                WHERE agent_id = '005WG00000A4lQnYAJ'
            )
        ) --AND (cast(ad.last_modified_date as date) BETWEEN '2025-01-16' AND '2025-01-23') 

        
 -----------------------------------------       
        
WITH DecodedFilters AS (
    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
),
CombinedFilters AS (
    SELECT 
        'zip_cd = ' || quote_literal(zip_cd) || ' AND isacc = false' AS combined_filter
    FROM DecodedFilters
),
DealerInfo AS (
    SELECT DISTINCT dealer_id
    FROM "mapping"."Teams"
    WHERE agent_id = '005WG00000A4lQnYAJ'
),
AgentInfo AS (
    SELECT DISTINCT agent_id
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
    SELECT DISTINCT
        ad.txt_audience_id,
        ad.txt_lead_disposition,
        ad.last_modified_date, ad.rn
    FROM (
        SELECT 
            ad.txt_audience_id,
            ad.txt_lead_disposition,
            ad.last_modified_date,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.txt_lead_disposition IS NOT NULL
    ) ad
    WHERE ad.rn = 1
)
SELECT
    COUNT(DISTINCT tm.agent_id) AS total_agents, tm.agent_id, t.territory_id, t.territory_name,
    COUNT(DISTINCT t.territory_id) AS total_territories,
    COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count,
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
             AND (CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23') 
        THEN p.audience_id
    END) AS sales_conversion_count,
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
             AND (CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23') 
        THEN p.audience_id
    END) AS comeback_count,
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Follow up Appointment') 
             AND (CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23') 
        THEN p.audience_id
    END) AS to_be_visited_count,
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) 
             AND (CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23')  
       THEN p.audience_id
    END) AS do_not_knock_count
FROM
   pgadmin."Prospect_partition" p
        LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id  AND ad.rn = 1
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd  
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        JOIN CombinedFilters cf ON (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        WHERE ad.txt_lead_disposition is not null --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))
         and 
         ST_Contains(
                    tg.geom,
                    ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
                ) and t.expiration_date >= current_date and t.isactive is not false 
    
        and tm.agent_id IN (
            SELECT agent_id
            FROM "mapping"."Teams"
            WHERE dealer_id IN (
                SELECT dealer_id
                FROM "mapping"."Teams"
                WHERE agent_id = '005WG00000A4lQnYAJ'
            )
        ) and t.expiration_date >= current_date and t.isactive is not false
        AND t.territory_id IN (
            SELECT territory_id
            FROM "mapping"."Territory"
           WHERE territory_id IN (
                SELECT t2.territory_id
                FROM TerritoryInfo t2
                JOIN territory_geometries tg ON tg.territory_id = t2.territory_id
            )) and t.territory_id = '76d88455-e83e-4868-b9df-0da2d3753125'
        group by tm.agent_id, t.territory_id, t.territory_name
        
005WG00000AGhXxYAL 76d88455-e83e-4868-b9df-0da2d3753125

SELECT * 
FROM public.get_lead_counts_nds_2(
    '005WG00000AGhXxYAL', -- agent_id
    '2025-01-16',         -- start_date
    '2025-01-23',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all',                -- p_lead_type
    ARRAY['76d88455-e83e-4868-b9df-0da2d3753125'] -- p_territory_ids (array with one territory_id)
);

SELECT * 
FROM public.get_lead_counts_nds_2(
    '005WG00000A4lQnYAJ', -- agent_id
    '2025-01-16',         -- start_date
    '2025-01-23',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'              -- p_lead_type
);

SELECT * 
FROM public.get_agent_and_team_counts_test(
    '005WG00000A4lQnYAJ', -- agent_id
    '2025-01-17',         -- start_date
    '2025-01-24',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all' , ARRAY['76d88455-e83e-4868-b9df-0da2d3753125']             -- p_lead_type-- p_territory_ids (array with one territory_id)
);
{"team_counts": {"comeback_avg": 1.00, "total_agents": 2, "my_lead_count": 72, "comeback_count": 2, "do_not_knock_avg": 7.00, "team_member_count": 36.00, "to_be_visited_avg": 8.00, 
"total_territories": 1, "do_not_knock_count": 14, "to_be_visited_count": 16, "sales_conversion_avg": 7.00, "sales_conversion_count": 14}, 
"agent_counts": {"comeback": 1, "do_not_knock": 7, "to_be_visited": 8, "sales_conversion": 7, "total_lead_count": 36}}

{"team_counts": {"comeback_avg": 0.00, "total_agents": 2, "my_lead_count": 90, "comeback_count": 0, "do_not_knock_avg": 0.00, "team_member_count": 45.00, 
"to_be_visited_avg": 0.00, "total_territories": 1, "do_not_knock_count": 0, "to_be_visited_count": 0, "sales_conversion_avg": 0.00, "sales_conversion_count": 0},
"agent_counts": {"comeback": 0, "do_not_knock": 0, "to_be_visited": 0, "sales_conversion": 0, "total_lead_count": 36}}

SELECT * 
FROM public.get_agent_and_team_counts_test(
    '005WG00000A4lQnYAJ', -- agent_id
    '2025-01-16',         -- start_date
    '2025-01-23',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'           -- p_lead_type-- p_territory_ids (array with one territory_id)
);
{"team_counts": {"comeback_avg": 1.00, "total_agents": 2, "my_lead_count": 72, "comeback_count": 2, "do_not_knock_avg": 7.00, "team_member_count": 36.00, "to_be_visited_avg": 8.00, 
"total_territories": 1, "do_not_knock_count": 14, "to_be_visited_count": 16, "sales_conversion_avg": 7.00, "sales_conversion_count": 14},
"agent_counts": {"comeback": 1, "do_not_knock": 7, "to_be_visited": 8, "sales_conversion": 7, "total_lead_count": 36}}

SELECT * 
FROM public.get_agent_and_team_counts(
    '005WG00000A4lQnYAJ', -- agent_id
    NULL,         -- start_date
    NULL,         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'           -- p_lead_type-- p_territory_ids (array with one territory_id)
);

SELECT * 
FROM public.get_agent_and_team_counts(
    p_agent_id => '005WG00000A4lQnYAJ',
    p_state_cd => '{}',
    p_lead_type => 'all'
);

SELECT * 
FROM public.get_agent_and_team_counts(
    '005WG00000A4lQnYAJ', -- agent_id
    '',         -- start_date
  '',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'           -- p_lead_type-- p_territory_ids (array with one territory_id)
);


SELECT * 
FROM public.get_agent_and_team_counts_test(
    '005WG00000A4lQnYAJ', -- agent_id
    '2025-01-16',         -- start_date
    '2025-01-23',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'            -- p_lead_type-- p_territory_ids (array with one territory_id)
);
{"team_counts": {"comeback_avg": 5.00, "total_agents": 7, "my_lead_count": 1598, "comeback_count": 38, "do_not_knock_avg": 8.00, "team_member_count": 228.00, 
"to_be_visited_avg": 8.00, "total_territories": 22, "do_not_knock_count": 61, "to_be_visited_count": 57, "sales_conversion_avg": 7.00, "sales_conversion_count": 55}, 
"agent_counts": {"comeback": 17, "do_not_knock": 29, "to_be_visited": 26, "sales_conversion": 29, "total_lead_count": 724}}
SELECT * 
FROM public.get_agent_and_team_counts(
    '005WG00000A4lQnYAJ', -- agent_id
    '2025-01-16',         -- start_date
    '2025-01-23',         -- end_date
    '{}',                 -- p_state_cd (empty array)
    'all'            -- p_lead_type-- p_territory_ids (array with one territory_id)
);
{"team_counts": {"comeback_avg": 28.00, "total_agents": 7, "my_lead_count": 1638, "comeback_count": 199, "do_not_knock_avg": 58.00, "team_member_count": 234.00, 
"to_be_visited_avg": 43.00, "total_territories": 25, "do_not_knock_count": 406, "to_be_visited_count": 302, "sales_conversion_avg": 48.00, "sales_conversion_count": 337}, 
"agent_counts": {"comeback": 17, "do_not_knock": 30, "to_be_visited": 23, "sales_conversion": 30, "total_lead_count": 724}}


WITH DecodedFilters AS (
    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
),
CombinedFilters AS (
    SELECT 
        'zip_cd = ' || quote_literal(zip_cd) || ' AND isacc = false' AS combined_filter
    FROM DecodedFilters
),
DealerInfo AS (
    SELECT DISTINCT dealer_id
    FROM "mapping"."Teams"
    WHERE agent_id = '005WG00000A4lQnYAJ'
),
AgentInfo AS (
    SELECT DISTINCT agent_id
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
    SELECT DISTINCT
        ad.txt_audience_id,
        ad.txt_lead_disposition,
        ad.last_modified_date, ad.rn
    FROM (
        SELECT 
            ad.txt_audience_id,
            ad.txt_lead_disposition,
            ad.last_modified_date,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE ad.txt_lead_disposition IS NOT NULL
    ) ad
    WHERE ad.rn = 1
)
SELECT
    COUNT(DISTINCT tm.agent_id) AS total_agents,
    tm.agent_id,
    t.territory_id,
    t.territory_name,
    COUNT(DISTINCT t.territory_id) AS total_territories,

    -- Total Lead Count (Unique to Each Agent)
    COUNT(DISTINCT CASE 
        WHEN tm.agent_id IS NOT NULL THEN p.audience_id 
    END) AS total_lead_count,

    -- Sales Conversion Count
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id || tm.agent_id -- Unique combination of audience_id and agent_id
    END) AS sales_conversion_count,

    -- Comeback Count
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id || tm.agent_id
    END) AS comeback_count,

    -- To Be Visited Count
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Follow up Appointment') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id || tm.agent_id
    END) AS to_be_visited_count,

    -- Do Not Knock Count
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 
            'Employee/Retiree', 'Existing Customer', 'Health Concern', 'Installation Timing', 
            'Language Barrier - Spanish', 'Language Barrier - Other', 'Moving', 'Not Interested', 
            'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract', 'ACC Bulk', 
            'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request', 
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 
            'Seasonal', 'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id || tm.agent_id
    END) AS do_not_knock_count
FROM
    pgadmin."Prospect_partition" p
LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id AND ad.rn = 1
JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd  
JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id 
JOIN territory_geometries tg ON tg.territory_id = t.territory_id
WHERE CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23' and
ad.txt_lead_disposition IS NOT NULL
  --AND t.territory_id = '76d88455-e83e-4868-b9df-0da2d3753125' -- Restrict by specific territory if needed
  AND tm.agent_id IN (
        SELECT agent_id
        FROM "mapping"."Teams"
        WHERE dealer_id IN (
            SELECT dealer_id
            FROM "mapping"."Teams"
            WHERE agent_id = '005WG00000A4lQnYAJ' -- Replace with the input agent_id
        )
    )
  AND t.expiration_date >= CURRENT_DATE
  AND t.isactive IS NOT FALSE
GROUP BY tm.agent_id, t.territory_id, t.territory_name --, cast(ad.last_modified_date as date)



Fetch distinct attribute_filter__c values from salesforce.zip_code__c
Check if the value is correct or not using this function


select * from public.decode_base64_and_fetch_original('tdv8RbKG8p82myWw4vcp08_B2l5AtYYoup8QlA9H1uY====================================================================================================================================================================================================================')

select distinct(attribute_filter__c) from salesforce.zip_code__c

If you get proper where clause like 'AND isacc = false'  , then its correct
If you get an encoded string in return, then set the value for that attribute filter using this query:


WITH DecodedFilters AS (
    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
),
CombinedFilters AS (
    SELECT 
        'zip_cd = ' || quote_literal(zip_cd) || ' AND isacc = false' AS combined_filter
    FROM DecodedFilters
),
DealerInfo AS (
    SELECT DISTINCT dealer_id
    FROM "mapping"."Teams"
    WHERE agent_id = '005WG00000A4lQnYAJ'
),
AgentInfo AS (
    SELECT DISTINCT agent_id
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
            ad.txt_lead_disposition,
            ad.last_modified_date,
            ROW_NUMBER() OVER (
                PARTITION BY ad.txt_audience_id
                ORDER BY ad.last_modified_date DESC NULLS LAST
            ) AS rn
        FROM pgadmin."AgentDisposition" ad
        WHERE --ad.last_modified_date is not null and 
        ad.txt_lead_disposition is not null 
)
SELECT
    tm.agent_id,
    t.territory_id,
    t.territory_name,

    -- Total Lead Count (Team Level)
    COUNT(DISTINCT tm.agent_id) AS total_agents,
            COUNT(DISTINCT t.territory_id) AS total_territories,
            COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count,

    -- Sales Conversion Count (Team Level)
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id
    END) AS team_sales_conversion_count,

    -- Sales Conversion Count (Agent Level)
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id
    END) AS agent_sales_conversion_count,

    -- Comeback Count (Team Level)
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id
    END) AS team_comeback_count,

    -- Comeback Count (Agent Level)
    COUNT(DISTINCT CASE 
        WHEN ad.txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') 
             AND CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
        THEN p.audience_id
    END) AS agent_comeback_count

FROM
    pgadmin."Prospect_partition" p
LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id AND ad.rn = 1
JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd  
JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id 
JOIN territory_geometries tg ON tg.territory_id = t.territory_id
WHERE
    --CAST(ad.last_modified_date AS DATE) BETWEEN '2025-01-16' AND '2025-01-23'
    --AND ad.txt_lead_disposition IS NOT NULL
    t.expiration_date >= CURRENT_DATE
    AND t.isactive IS NOT false
    and tm.agent_id IN (
            SELECT agent_id
            FROM "mapping"."Teams"
            WHERE dealer_id IN (
                SELECT dealer_id
                FROM "mapping"."Teams"
                WHERE agent_id = '005WG00000A4lQnYAJ'
            )
        )
        AND t.territory_id IN (
            SELECT territory_id
            FROM "mapping"."Territory"
            WHERE territory_id IN (
                SELECT t2.territory_id
                FROM TerritoryInfo t2
                JOIN territory_geometries tg ON tg.territory_id = t2.territory_id))
GROUP BY
    tm.agent_id, t.territory_id, t.territory_name



CREATE INDEX idx_attribute_filter ON salesforce.zip_code__c (attribute_filter__c);

select distinct(attribute_filter__c) from salesforce.zip_code__c

update salesforce.zip_code__c set attribute_filter__c = 'zWL3Mo3unZQFJKlKxUw09HWZvSbsJPVyy3oE2P0Bi5E====================================================================================================================================================================================================================' where name  = '75037'

select * from pgadmin."AgentDisposition" where txt_audience_id = '644253046'

select * from pgadmin."Prospect_partition" where audience_id = '644253046'