with DealerInfo AS(
        SELECT dealer_id
        FROM "mapping"."Teams"
        --WHERE agent_id = '0055c00000AypyrAAB'
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
          
                 -- AND t2.territory_id = '23aa5a52-74a0-4889-9565-86dac0b49e6e'
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
            AND t.isactive IS NOT false --and t.territory_id = '23aa5a52-74a0-4889-9565-86dac0b49e6e'
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
    )
    select distinct p.audience_id, tm.agent_id, t.territory_id, p.zip_cd,
   ST_Contains(
                  tg.geom,
                 ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326))
           from  pgadmin."Prospect_partition" p
        left join pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id --AND ad.rn = 1
        JOIN "mapping"."Territory" t ON p.zip_cd = t.zip_cd --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))  
        JOIN "mapping"."Teams" tm ON tm.territory_id = t.territory_id
        JOIN territory_geometries tg ON tg.territory_id = t.territory_id
        WHERE tm.agent_id IN (
            SELECT agent_id
            FROM "mapping"."Teams"
            WHERE dealer_id IN (
                SELECT dealer_id
                FROM "mapping"."Teams"
                --WHERE agent_id = '0055c00000AypyrAAB'
            )
        )
        and t.expiration_date >= current_date
       and ST_Contains(
              tg.geom,
             ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326))
                
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
                   ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326))
            ))

        AND CAST(ad.last_modified_date AS date) BETWEEN '2025-01-10' AND '2025-01-20'
 
        --and t.territory_id = 'e1122a86-cc34-48b7-b5a2-0e6fa811e9d8'
        
        and t.territory_id = '23aa5a52-74a0-4889-9565-86dac0b49e6e';

-----------------------------------------------------------------------------------------------------------------

WITH DecodedFilters AS (
	    SELECT 
	        z.name AS zip_cd, 
	        decode_base64_and_fetch_original(z.attribute_filter__c) AS decoded_filter
	    FROM salesforce.zip_code__c z
	    JOIN "mapping"."Territory" t ON z.name = t.zip_cd
	    WHERE t.expiration_date >= CURRENT_DATE
	      AND t.isactive IS NOT FALSE
	     -- AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids))
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
           -- AND (p_territory_ids IS NULL OR p_territory_ids = '{}' OR t.territory_id = ANY(p_territory_ids))
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
        WHERE ad.last_modified_date IS NOT null and txt_lead_disposition is not null
        -- cast(ad.last_modified_date as date) between '2025-01-10' and '2025-01-17'
    ),
    matching_audience_ids AS (
        SELECT
            p.audience_id,
            ld.txt_audience_id,
            ld.txt_lead_disposition,
            t.territory_id
        FROM
            pgadmin."Prospect_partition" p
        JOIN
            mapping."Territory" t ON p.zip_cd = t.zip_cd --AND (p_state_cd IS NULL OR p_state_cd =  '{}' OR p.state_cd = ANY(p_state_cd))  
        JOIN
            territory_geometries tg ON tg.territory_id = t.territory_id
        LEFT JOIN
            latest_dispositions ld
            ON p.audience_id = ld.txt_audience_id AND ld.rn = 1 -- Only the latest disposition
        JOIN
            mapping."Teams" tm ON tm.territory_id = t.territory_id
        WHERE
            tm.agent_id = '005Pr000007rXHxIAM'          
            AND t.expiration_date >= CURRENT_DATE
            AND ST_Contains(
                tg.geom,
                ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
            )
            AND EXISTS (
            SELECT 1 
            FROM CombinedFilters cf 
            WHERE cf.combined_filter IS NOT NULL 
              -- Check if combined filter applies to zip codes dynamically.
              AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        )
            --AND CAST(ld.last_modified_date AS date) BETWEEN start_date AND end_date  --OR ld.last_modified_date IS NULL)
            AND t.isactive IS NOT FALSE
           -- AND (p_lead_type = 'all' OR ld.txt_lead_disposition = p_lead_type) -- Filter by lead type
            --AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids)) -- Filter by territory IDs
            
 )
    select COUNT(DISTINCT audience_id),COUNT(DISTINCT txt_audience_id), txt_lead_disposition, territory_id
    from matching_audience_ids  where txt_lead_disposition is not null
    group by txt_lead_disposition, territory_id
    
select query, wait_event, wait_event_type from pg_stat_activity where state = 'active' 

SELECT json_agg(result)
FROM public.get_manager_dealer_data('0018b000025j7XSAAY', '2025-01-01', '2025-01-21')AS result;

[{"sfid":"0015c00002eT05NAAS","name":"Adventure Dealer","zip_codes":"01031, 01033, 01034, 01035, 01039, 01057, 01066, 49037, 76065","zip_code_count":9,"total_lead_count":4431888,"sales_conversion_count":23922,"comeback_count":13518,"to_be_visited_count":15039,"do_not_knock_count":40248,"total_pending_disposition":3557628}, 
 {"sfid":"0018b000025j7XSAAY","name":"Andrea's Dummy Dealer","zip_codes":"01001, 01007, 01009, 01020, 01029, 01037, 01069, 03902, 03903, 03905, 03907, 07071, 22802, 23703, 27105, 27106, 27357, 27401, 27405, 27513, 27603, 27610, 27864, 28027, 28214, 28215, 28803, 29334, 29456, 29464, 29501, 30008, 30022, 30041, 30044, 30064, 30078, 30080, 30082, 30269, 30310, 30606, 30701, 31220, 31562, 32080, 32081, 32082, 32083, 32084, 32085, 32086, 32087, 32091, 32092, 32094, 32095, 32096, 32097, 32234, 32353, 32357, 32358, 32359, 32360, 32361, 32402, 32403, 32462, 32464, 32465, 32466, 32501, 32502, 32503, 32607, 32609, 32615, 32617, 32618, 32619, 32626, 33004, 33040, 33042, 33401, 35772, 37013, 37020, 37040, 37051, 37055, 37127, 37130, 37203, 37303, 37325, 37411, 37711, 37757, 37890, 37920, 37938, 38058, 38125, 38487, 38901, 39325, 40031, 40057, 40207, 40215, 40299, 42406, 44436, 45369, 46242, 46511, 47130, 47232, 47601, 47875, 48006, 48060, 501, 55046, 60140, 62306, 63771, 68123, 70726, 72327, 72450, 75217, 77049, 77095, 77546, 77802, 78744, 78839, 79369, 79370, 79379, 90745, 91932, 93117, 93206, 94564, 94565, 95821, 98311","zip_code_count":151,"total_lead_count":110504,"sales_conversion_count":5928,"comeback_count":14592,"to_be_visited_count":760,"do_not_knock_count":9880,"total_pending_disposition":245176}, 
 {"sfid":"001WG00000Eo3ayYAB","name":"Dummy Dealer 2","zip_codes":"01028, 01144, 75211","zip_code_count":3,"total_lead_count":51,"sales_conversion_count":0,"comeback_count":0,"to_be_visited_co


[{"sfid":"0015c00002eT05NAAS","name":"Adventure Dealer","zip_codes":"01031, 01033, 01034, 01035, 01039, 01057, 01066, 49037, 76065",
"zip_code_count":9,"total_lead_count":1090413,"sales_conversion_count":7056,"comeback_count":3483,"to_be_visited_count":1287,"do_not_knock_count":28566,"total_pending_disposition":2657961}, 

 {"sfid":"001WG00000Eo3ayYAB","name":"Dummy Dealer 2","zip_codes":"01028, 01144, 75211","zip_code_count":3,
"total_lead_count":51,"sales_conversion_count":0,"comeback_count":0,"to_be_visited_count":6,"do_not_knock_count":0,"total_pending_disposition":96}]

