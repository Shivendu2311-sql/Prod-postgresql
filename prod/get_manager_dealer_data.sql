-- DROP FUNCTION public.get_manager_dealer_data(text, date, date);

CREATE OR REPLACE FUNCTION public.get_manager_dealer_data(p_sfid text, p_start_date date, p_end_date date)
 RETURNS TABLE(sfid character varying, name text, zip_codes text, zip_code_count integer, total_lead_count integer, sales_conversion_count integer, comeback_count integer, to_be_visited_count integer, do_not_knock_count integer, total_pending_disposition integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
    start_time timestamp := clock_timestamp();
    step_time timestamp;
BEGIN
    -- Log start of the function
    RAISE NOTICE 'Function started at: %', start_time;
   DROP TABLE IF EXISTS temp_account_hierarchy;
    -- Step 1: Recursive CTE to build account hierarchy
    step_time := clock_timestamp();
    CREATE TEMP TABLE temp_account_hierarchy AS
    WITH RECURSIVE account_hierarchy AS (
        SELECT DISTINCT
            a1.sfid, 
            a1.name::text,  
            a1.parentid, 
            c.sfid AS cid, 
            u.sfid AS uid,
            u.master_acct_id__c, 
            u.accountid__c, 
            u.dealeraccid__c, 
            u.isagent__c, 
            u.email::text,  
            zcc.external_zip_code__c::text,  
            1 AS level
        FROM salesforce.account a1
        LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
        LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
        LEFT JOIN salesforce.zip_code__c zcc ON a1.sfid = zcc.last_assigned_dealer__c
        WHERE a1.sfid = p_sfid and ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))

        UNION ALL

        SELECT DISTINCT
            a.sfid, 
            a.name::text,  
            a.parentid, 
            c.sfid AS cid, 
            u.sfid AS uid,
            u.master_acct_id__c, 
            u.accountid__c, 
            u.dealeraccid__c, 
            u.isagent__c, 
            u.email::text,  
            zcc.external_zip_code__c::text,  
            ah.level + 1 AS level
        FROM salesforce.account a
        LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
        LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
        LEFT JOIN salesforce.zip_code__c zcc ON a.sfid = zcc.last_assigned_dealer__c
        INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
        WHERE --ah.level < 10 and 
         ((zcc.end_date__c IS NULL) OR (zcc.end_date__c >= CURRENT_DATE))
    )
    SELECT * FROM account_hierarchy;
    RAISE NOTICE 'Step 1 complete: account_hierarchy built in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - step_time);
    
    DROP TABLE IF EXISTS temp_dealer_hie;
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
   
    DROP TABLE IF EXISTS temp_agent_metrics;
    -- Step 3: Final aggregation and metrics
    step_time := clock_timestamp();
    CREATE TEMP TABLE temp_agent_metrics AS
    SELECT 
        d.sfid,
        d.name,
        d.external_zip_code__c,
        COUNT(DISTINCT p.audience_id)::integer AS total_lead_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale') THEN 1 END)::integer AS sales_conversion_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer') THEN 1 END)::integer AS comeback_count,
        COUNT(CASE WHEN txt_lead_disposition IN ('Follow up Appointment') THEN 1 END)::integer AS to_be_visited_count,
        COUNT(CASE WHEN txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ) THEN 1 END)::integer AS do_not_knock_count,
        COUNT(CASE WHEN txt_lead_disposition NOT IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot', 'Decision Maker Not Home', 'No Answer',
            'Follow up Appointment', 'Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale'
        ) THEN 1 END)::integer AS total_pending_disposition
    FROM temp_dealer_hie d
    JOIN "mapping"."Teams" tm ON d.uid = tm.dealer_id 
    JOIN "mapping"."Territory" t ON tm.territory_id = t.territory_id
    JOIN pgadmin."Prospect" p ON p.zip_cd = t.zip_cd
    LEFT JOIN pgadmin."AgentDisposition" ad ON p.audience_id = ad.txt_audience_id
    WHERE 
       --AND (d.dealer_type IN ('Manager Dealer', 'Regional Dealer') 
        d.sfid != p_sfid
    AND CAST(ad.last_modified_date AS date) BETWEEN p_start_date AND p_end_date
    GROUP BY d.sfid, d.name, d.external_zip_code__c;
    RAISE NOTICE 'Step 3 complete: agent metrics aggregated in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - step_time);

    -- Final step: Aggregate results
    RETURN QUERY
    SELECT 
        temp_agent_metrics.sfid,
        temp_agent_metrics.name,
        STRING_AGG(DISTINCT temp_agent_metrics.external_zip_code__c, ', ') AS zip_codes,
        COUNT(DISTINCT temp_agent_metrics.external_zip_code__c)::integer AS zip_code_count,
        SUM(temp_agent_metrics.total_lead_count)::integer AS total_lead_count,
        SUM(temp_agent_metrics.sales_conversion_count)::integer AS sales_conversion_count,
        SUM(temp_agent_metrics.comeback_count)::integer AS comeback_count,
        SUM(temp_agent_metrics.to_be_visited_count)::integer AS to_be_visited_count,
        SUM(temp_agent_metrics.do_not_knock_count)::integer AS do_not_knock_count,
        SUM(temp_agent_metrics.total_pending_disposition)::integer AS total_pending_disposition
    FROM temp_agent_metrics
    GROUP BY temp_agent_metrics.sfid, temp_agent_metrics.name;

    RAISE NOTICE 'Function completed in % seconds', EXTRACT(EPOCH FROM clock_timestamp() - start_time);
END;
$function$
;
