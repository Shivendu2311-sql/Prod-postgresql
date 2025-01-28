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
       -- WHERE ad.txt_lead_disposition is not null 
          --and cast(ad.last_modified_date as date) BETWEEN start_date AND end_date 
		

    )
    
    SELECT
    COUNT(DISTINCT tm.agent_id) AS total_agents,
    COUNT(DISTINCT t.territory_id) AS total_territories,
    COUNT(DISTINCT (p.audience_id, tm.agent_id)) AS my_lead_count
   

FROM
            pgadmin."Prospect_partition" p
        LEFT JOIN latest_dispositions ad ON p.audience_id = ad.txt_audience_id  AND ad.rn = 1
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd  
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        JOIN CombinedFilters cf ON (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        WHERE --ad.txt_lead_disposition is not null --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))
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
        )

        
        
select distinct tm.territory_id 
from "mapping"."Teams" tm join mapping."Territory" t on 
  tm.territory_id = t.territory_id 
  where tm.dealer_id in (select dealer_id from "mapping"."Teams" where agent_id = '005WG00000A4lQnYAJ')  
  and t.isactive is not false and t.expiration_date >= current_date
                