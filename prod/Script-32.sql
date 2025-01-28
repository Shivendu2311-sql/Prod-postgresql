WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email,zcc.external_zip_code__c,
           CASE 
               WHEN parentid IS NULL THEN 1
               ELSE 2
           END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    left join mv_filtered_zip_code zcc on a1.sfid = zcc.last_assigned_dealer__c -- added 
    WHERE a1.sfid = '0018b000025j7XSAAY' --AND (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE) -- added
    
    UNION ALL
    
    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email,zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    left join mv_filtered_zip_code zcc on a.sfid = zcc.last_assigned_dealer__c -- added
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid 
    WHERE ah.level < 10 -- Limit recursion depth
),
dealer_hie AS (
    SELECT distinct
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

        else 'Unknown'
        
    END AS dealer_type
    FROM account_hierarchy ah
)
    SELECT 
        d.sfid,
        d.name,
        d.external_zip_code__c,
        tm.agent_id,
        COUNT(Distinct p.audience_id) AS total_lead_count,
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
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id --and t.isactive is not false and t.expiration_date >= current_date
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE CAST(ad.last_modified_date AS date) BETWEEN '2025-01-11' AND '2025-01-22'
       and (d.dealer_type IN ('Manager Dealer', 'Regional Dealer') and d.sfid != '0018b000025j7XSAAY') --and name not like '%Test%'-- added
    GROUP BY d.sfid, d.name, d.external_zip_code__c, tm.agent_id
--CREATE MATERIALIZED VIEW mv_filtered_zip_code AS
--SELECT *
--FROM salesforce.zip_code__c
--WHERE end_date__c IS NULL OR end_date__c >= CURRENT_DATE;
    
    
WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT DISTINCT
        a1.sfid, 
        a1.name, 
        a1.parentid, 
        c.sfid AS cid, 
        u.sfid AS uid,
        u.master_acct_id__c, 
        u.accountid__c, 
        u.dealeraccid__c, 
        u.isagent__c, 
        u.email,
        zcc.external_zip_code__c,
        1 AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN mv_filtered_zip_code zcc ON a1.sfid = zcc.last_assigned_dealer__c
    WHERE a1.sfid = '0018b000025j7XSAAY'

    UNION ALL

    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT DISTINCT
        a.sfid, 
        a.name, 
        a.parentid, 
        c.sfid AS cid, 
        u.sfid AS uid,
        u.master_acct_id__c, 
        u.accountid__c, 
        u.dealeraccid__c, 
        u.isagent__c, 
        u.email,
        zcc.external_zip_code__c,
        ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN mv_filtered_zip_code zcc ON a.sfid = zcc.last_assigned_dealer__c
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
    WHERE ah.level < 10 -- Limit recursion depth
),
dealer_hie AS (
    SELECT 
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
                 AND (ah.master_acct_id__c IS NOT NULL
                      AND ah.master_acct_id__c = ah.accountid__c 
                      AND ah.master_acct_id__c = ah.dealeraccid__c) 
              THEN 'Master Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NOT NULL 
                 AND ah.accountid__c = ah.dealeraccid__c 
                 AND ah.accountid__c != ah.master_acct_id__c
              THEN 'Manager Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NULL 
                 AND ah.accountid__c = ah.dealeraccid__c
              THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
),
final_aggregation AS (
    SELECT 
        d.sfid,
        d.name,
        STRING_AGG(DISTINCT d.external_zip_code__c, ', ') AS zip_codes,
        COUNT(DISTINCT d.external_zip_code__c) AS zip_code_count,
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
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE CAST(ad.last_modified_date AS date) BETWEEN '2025-01-11' AND '2025-01-22'
       AND (d.dealer_type IN ('Manager Dealer', 'Regional Dealer') AND d.sfid != '0018b000025j7XSAAY')
    GROUP BY d.sfid, d.name, tm.agent_id
)
SELECT 
    sfid,
    name,
    STRING_AGG(DISTINCT zip_codes, ', ') AS zip_codes,
    COUNT(DISTINCT zip_codes) AS zip_code_count,
    SUM(total_lead_count) AS total_lead_count,
    SUM(sales_conversion_count) AS sales_conversion_count,
    SUM(comeback_count) AS comeback_count,
    SUM(to_be_visited_count) AS to_be_visited_count,
    SUM(do_not_knock_count) AS do_not_knock_count,
    SUM(total_pending_disposition) AS total_pending_disposition
FROM final_aggregation
GROUP BY sfid, name;
    

SELECT json_agg(result)
FROM public.get_sales_conversion_per_month('0018b000025j7XSAAY', '2024-01-01', '2024-12-31')as result;

[{"month_name":"January  ","sales_conversion_rate":0}, 
 {"month_name":"February ","sales_conversion_rate":0}, 
 {"month_name":"March    ","sales_conversion_rate":0}, 
 {"month_name":"April    ","sales_conversion_rate":0}, 
 {"month_name":"May      ","sales_conversion_rate":0}, 
 {"month_name":"June     ","sales_conversion_rate":0}, 
 {"month_name":"July     ","sales_conversion_rate":0}, 
 {"month_name":"August   ","sales_conversion_rate":0}, 
 {"month_name":"September","sales_conversion_rate":0}, 
 {"month_name":"October  ","sales_conversion_rate":0.22197558268590455000}, 
 {"month_name":"November ","sales_conversion_rate":0.00000000000000000000}, 
 {"month_name":"December ","sales_conversion_rate":6.27027027027027027000}]


drop table temp_dealer_hie

SELECT json_agg(result)
FROM public.get_manager_dealer_data_3('0018b000025j7XSAAY', '2025-01-11', '2025-01-22')AS result;

SELECT json_agg(result)
FROM public.get_manager_dealer_data('0018b000025j7XSAAY', '2025-01-20', '2025-01-22')AS result;

SELECT *
FROM public.get_manager_dealer_data_3('0018b000025j7XSAAY', '2025-01-11', '2025-01-22')

CREATE OR REPLACE FUNCTION public.get_manager_dealer_data_3(
    p_sfid text,
    p_start_date date,
    p_end_date date
)
RETURNS TABLE(
    sfid character varying,
    name text,
    zip_codes text,
    zip_code_count integer,
    total_lead_count integer,
    sales_conversion_count integer,
    comeback_count integer,
    to_be_visited_count integer,
    do_not_knock_count integer,
    total_pending_disposition integer
)
LANGUAGE sql
AS $function$
WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT DISTINCT
        a1.sfid, 
        a1.name, 
        a1.parentid, 
        c.sfid AS cid, 
        u.sfid AS uid,
        u.master_acct_id__c, 
        u.accountid__c, 
        u.dealeraccid__c, 
        u.isagent__c, 
        u.email,
        zcc.external_zip_code__c,
        1 AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN mv_filtered_zip_code zcc ON a1.sfid = zcc.last_assigned_dealer__c
    WHERE a1.sfid = p_sfid

    UNION ALL

    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT DISTINCT
        a.sfid, 
        a.name, 
        a.parentid, 
        c.sfid AS cid, 
        u.sfid AS uid,
        u.master_acct_id__c, 
        u.accountid__c, 
        u.dealeraccid__c, 
        u.isagent__c, 
        u.email,
        zcc.external_zip_code__c,
        ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN mv_filtered_zip_code zcc ON a.sfid = zcc.last_assigned_dealer__c
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
    WHERE ah.level < 10 -- Limit recursion depth
),
dealer_hie AS (
    SELECT 
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
                 AND (ah.master_acct_id__c IS NOT NULL
                      AND ah.master_acct_id__c = ah.accountid__c 
                      AND ah.master_acct_id__c = ah.dealeraccid__c) 
              THEN 'Master Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NOT NULL 
                 AND ah.accountid__c = ah.dealeraccid__c 
                 AND ah.accountid__c != ah.master_acct_id__c
              THEN 'Manager Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NULL 
                 AND ah.accountid__c = ah.dealeraccid__c
              THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
),
final_aggregation AS (
    SELECT 
        d.sfid,
        d.name,
        STRING_AGG(DISTINCT d.external_zip_code__c, ', ') AS zip_codes,
        COUNT(DISTINCT d.external_zip_code__c) AS zip_code_count,
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
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE CAST(ad.last_modified_date AS date) BETWEEN p_start_date AND p_end_date
       AND (d.dealer_type IN ('Manager Dealer', 'Regional Dealer') AND d.sfid != p_sfid)
    GROUP BY d.sfid, d.name, tm.agent_id
)
SELECT 
    sfid,
    name,
    STRING_AGG(DISTINCT zip_codes, ', ') AS zip_codes,
    COUNT(DISTINCT zip_codes) AS zip_code_count,
    SUM(total_lead_count) AS total_lead_count,
    SUM(sales_conversion_count) AS sales_conversion_count,
    SUM(comeback_count) AS comeback_count,
    SUM(to_be_visited_count) AS to_be_visited_count,
    SUM(do_not_knock_count) AS do_not_knock_count,
    SUM(total_pending_disposition) AS total_pending_disposition
FROM final_aggregation
GROUP BY sfid, name;
$function$;



CREATE OR REPLACE FUNCTION public.get_manager_dealer_data_3(
    p_sfid text,
    p_start_date date,
    p_end_date date
)
RETURNS TABLE(
    sfid character varying,
    name text,
    zip_codes text,
    zip_code_count integer,
    total_lead_count integer,
    sales_conversion_count integer,
    comeback_count integer,
    to_be_visited_count integer,
    do_not_knock_count integer,
    total_pending_disposition integer
)
LANGUAGE plpgsql
AS $function$
DECLARE
    start_time timestamp := clock_timestamp();
    step_time timestamp;
BEGIN
    -- Log start of the function
    RAISE NOTICE 'Function started at: %', start_time;

    -- Step 1: Recursive CTE to build account hierarchy
    step_time := clock_timestamp();
    CREATE TEMP TABLE temp_account_hierarchy AS
    WITH RECURSIVE account_hierarchy AS (
        SELECT DISTINCT
            a1.sfid, 
            a1.name, 
            a1.parentid, 
            c.sfid AS cid, 
            u.sfid AS uid,
            u.master_acct_id__c, 
            u.accountid__c, 
            u.dealeraccid__c, 
            u.isagent__c, 
            u.email,
            zcc.external_zip_code__c,
            1 AS level
        FROM salesforce.account a1
        LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
        LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
        LEFT JOIN mv_filtered_zip_code zcc ON a1.sfid = zcc.last_assigned_dealer__c
        WHERE a1.sfid = p_sfid

        UNION ALL

        SELECT DISTINCT
            a.sfid, 
            a.name, 
            a.parentid, 
            c.sfid AS cid, 
            u.sfid AS uid,
            u.master_acct_id__c, 
            u.accountid__c, 
            u.dealeraccid__c, 
            u.isagent__c, 
            u.email,
            zcc.external_zip_code__c,
            ah.level + 1 AS level
        FROM salesforce.account a
        LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
        LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
        LEFT JOIN mv_filtered_zip_code zcc ON a.sfid = zcc.last_assigned_dealer__c
        INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
        WHERE ah.level < 10
    )
    SELECT * FROM account_hierarchy;
    RAISE NOTICE 'Step 1 complete: account_hierarchy built in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - step_time);

    -- Step 2: Dealer hierarchy aggregation
    step_time := clock_timestamp();
    CREATE TEMP TABLE temp_dealer_hie AS
    SELECT 
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
                 AND (ah.master_acct_id__c IS NOT NULL
                      AND ah.master_acct_id__c = ah.accountid__c 
                      AND ah.master_acct_id__c = ah.dealeraccid__c) 
              THEN 'Master Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NOT NULL 
                 AND ah.accountid__c = ah.dealeraccid__c 
                 AND ah.accountid__c != ah.master_acct_id__c
              THEN 'Manager Dealer'
            WHEN (LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL)
                 AND ah.master_acct_id__c IS NULL 
                 AND ah.accountid__c = ah.dealeraccid__c
              THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM temp_account_hierarchy ah;
    RAISE NOTICE 'Step 2 complete: dealer_hie aggregated in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - step_time);

    -- Step 3: Final aggregation and metrics
    step_time := clock_timestamp();
    RETURN QUERY
    SELECT 
        d.sfid,
        d.name,
        STRING_AGG(DISTINCT d.external_zip_code__c, ', ') AS zip_codes,
        COUNT(DISTINCT d.external_zip_code__c) AS zip_code_count,
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
    FROM temp_dealer_hie d
    JOIN "mapping"."Teams" tm ON d.uid = tm.dealer_id 
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE CAST(ad.last_modified_date AS date) BETWEEN p_start_date AND p_end_date
       AND (d.dealer_type IN ('Manager Dealer', 'Regional Dealer') AND d.sfid != p_sfid)
    GROUP BY d.sfid, d.name, tm.agent_id;
    RAISE NOTICE 'Step 3 complete: final aggregation in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - step_time);

    -- Log end of the function
    RAISE NOTICE 'Function completed in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - start_time);
END;
$function$;
