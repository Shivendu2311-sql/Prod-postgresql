CREATE INDEX idx_unit_designator_cd_pp ON pgadmin."Prospect_partition"  (unit_designator_cd);

CREATE INDEX idx_unit_nbr ON pgadmin."Prospect_partition"  (unit_nbr);

CREATE INDEX idx_isfiber ON pgadmin."Prospect_partition" (isfiber);

CREATE INDEX idx_pstpd_wrls_subsrptn_sts_cd ON pgadmin."Prospect_partition" (pstpd_wrls_subsrptn_sts_cd); 

select distinct(t.territory_id ) from "mapping"."Territory" t
join pgadmin."Prospect_partition" p on t.zip_cd = p.zip_cd
--left join pgadmin."AgentDisposition" ad on p.audience_id = ad.txt_audience_id 
where --t.territory_id = '0988992a-0768-4dfe-bac3-a570b9e2f111'
 t.isactive is not false and t.expiration_date >= current_date

select * from  pgadmin."Prospect_partition" where zip_cd in ('01031','01033','01034')

SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE column_name like '%zip%' AND table_schema = 'salesforce';


analyze pgadmin."Prospect_partition" 

--VACUUM FULL pgadmin."Prospect_partition";

select * from "mapping".users

select distinct t.zip_cd, 
from salesforce."user" u 
join salesforce.account a on a.sfid = u.accountid  
left join salesforce.contact c on u.contactid = c.sfid
JOIN "mapping"."Teams" tm ON u.sfid = tm.dealer_id 
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
where a.sfid = '0018b000025j7XSAAY'

FROM salesforce.account a
    left join salesforce.contact c on a.sfid = c.accountid
    left join salesforce."user" u on u.contactid = c.sfid

select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ',
'2025-01-10','2025-01-20','{}','all')

select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ',
'2025-01-10','2025-01-17','{}','all', array['a0520bbe-05ae-42a7-83fd-1e1c47369af4'])

select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ',
'2025-01-10','2025-01-17','{}','wireless')

-- DROP FUNCTION public.get_agent_and_team_counts(text, date, date, _text, text, _varchar);
WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email,
           CASE 
               WHEN parentid IS NULL THEN 1
               ELSE 2
           END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    WHERE a1.sfid = '0018b000025j7XSAAY'
    
    UNION ALL
    
    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
),
dealer_hie AS (
    SELECT DISTINCT 
        ah.sfid, 
        ah.name, 
        ah.parentid,
        ah.email,
        ah.cid,
        ah.uid,
        ah.master_acct_id__c,
        ah.accountid__c,
        ah.dealeraccid__c,
        ah.isagent__c,
        CASE 
            -- Master Dealer logic
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
             AND (ah.master_acct_id__c IS NOT NULL
                 AND ah.master_acct_id__c = ah.accountid__c 
                 AND ah.master_acct_id__c = ah.dealeraccid__c) 
             THEN 'Master Dealer'
        
        -- Manager Dealer logic
        WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NOT NULL 
             AND ah.accountid__c = ah.dealeraccid__c 
             AND ah.accountid__c != ah.master_acct_id__c
             THEN 'Manager Dealer'
        
        -- Regional Dealer logic
        WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NULL 
             AND ah.accountid__c = ah.dealeraccid__c
             THEN 'Regional Dealer'
        
        -- Agent logic
        WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'

        
        ELSE 'Unknown'
    END AS dealer_type
    FROM account_hierarchy ah
)
select * from dealer_hie where name = 'Dummy_Dealer_2'

-- DROP FUNCTION public.get_agent_and_team_counts(text, date, date, _text, text, _varchar);

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
        where ad.txt_lead_disposition is not null
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
            mapping."Territory" t ON p.zip_cd = t.zip_cd 
        JOIN
            territory_geometries tg ON tg.territory_id = t.territory_id AND t.expiration_date >= CURRENT_DATE AND t.isactive IS NOT FALSE 
        LEFT JOIN
            latest_dispositions ld
            ON p.audience_id = ld.txt_audience_id AND ld.rn = 1 --and ld.txt_lead_disposition is not null -- Only the latest disposition
        JOIN
            mapping."Teams" tm ON tm.territory_id = t.territory_id
        WHERE 
          ld.txt_lead_disposition is not null and tm.agent_id = get_lead_counts_nds_2.agent_id  
          and ST_Contains(
                tg.geom,
                ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
            ) 
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
           AND EXISTS (
            SELECT 1 
            FROM CombinedFilters cf 
            WHERE cf.combined_filter IS NOT NULL 
              -- Check if combined filter applies to zip codes dynamically.
              AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        ) AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids)) 
            --AND CAST(ld.last_modified_date AS date) BETWEEN start_date AND end_date -- OR ld.last_modified_date IS NULL
           -- AND (p_lead_type = 'all' OR ld.txt_lead_disposition = p_lead_type) -- Filter by lead type
            -- Filter by territory IDs
 )
    SELECT
        COUNT(DISTINCT audience_id),
        COUNT(*) FILTER (WHERE txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale')),
         COUNT(*) FILTER (WHERE txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer')),
        COUNT(*) FILTER (WHERE txt_lead_disposition = 'Follow up Appointment'),
        COUNT(*) FILTER (WHERE txt_lead_disposition IN (
                'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
                'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
                'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
                'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
                'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
                'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
            ))
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
