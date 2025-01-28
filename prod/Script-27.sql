WITH RECURSIVE account_hierarchy AS ( -- 538840
    -- Base case: Select the account with the given sfid
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, --zcc.external_zip_code__c,
           CASE 
               WHEN parentid IS NULL THEN 1
               ELSE 2
           END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid and a1.sfid = '0018b000025j7XSAAY' 
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    left join salesforce.zip_code__c zcc on a1.sfid = zcc.last_assigned_dealer__c and (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    WHERE (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    
    UNION ALL
    
    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email,-- zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    left join salesforce.zip_code__c zcc on a.sfid = zcc.last_assigned_dealer__c and (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid   
),  --- 1,07,45,953, 10,623
dealer_hie AS (
    SELECT DISTINCT  
        ah.sfid, 
        ah.name, 
        ah.parentid,
        ah.email,
       -- ah.external_zip_code__c,
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


select * from dealer_hie where dealer_type in ('Manager Dealer', 'Regional Dealer')


    SELECT 
       -- d.sfid,
       -- d.name,
  distinct d.external_zip_code__c, --t.expiration_date,
        --tm.agent_id, t.isactive, t.expiration_date, t.territory_id,
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
    WHERE 
        --(t.isactive IS NULL OR t.isactive = true)
         -- (d.dealer_type = 'Manager Dealer'  or d.dealer_type = 'Regional Dealer')
           CAST(ad.last_modified_date AS date) BETWEEN '2024-01-31' AND '2025-01-21'
       --AND t.expiration_date >= CURRENT_DATE 
       and (name = 'Dummy Dealer 2' or name = 'Adventure Dealer')
    GROUP BY --d.sfid, d.name, p.zip_cd, tm.agent_id, t.isactive, t.expiration_date, t.territory_id
   d.external_zip_code__c
    
    


select pid, state, query, wait_event , wait_event_type  from pg_stat_activity where state = 'active' order by pid asc

WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           CASE WHEN parentid IS NULL THEN 1 ELSE 2 END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    INNER JOIN salesforce.zip_code__c zcc ON a1.sfid = zcc.last_assigned_dealer__c
    WHERE a1.sfid = '0018b000025j7XSAAY' AND (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    
    UNION ALL
    
    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    INNER JOIN salesforce.zip_code__c zcc ON a.sfid = zcc.last_assigned_dealer__c
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid
    WHERE (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
      AND ah.level < 10  -- Limit recursion depth, change 10 to an appropriate level if needed
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
                 AND ah.master_acct_id__c = ah.dealeraccid__c) THEN 'Master Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NOT NULL 
             AND ah.accountid__c = ah.dealeraccid__c 
             AND ah.accountid__c != ah.master_acct_id__c THEN 'Manager Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NULL 
             AND ah.accountid__c = ah.dealeraccid__c THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
)
SELECT *
FROM dealer_hie 
WHERE dealer_type IN ('Manager Dealer', 'Regional Dealer');

WITH RECURSIVE account_hierarchy AS (
    -- Base case: Select the account with the given sfid
    SELECT a1.sfid, a1.name, a1.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           CASE WHEN parentid IS NULL THEN 1 ELSE 2 END AS level
    FROM salesforce.account a1
    LEFT JOIN salesforce.contact c ON a1.sfid = c.accountid AND a1.sfid = '0018b000025j7XSAAY' 
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a1.sfid = zcc.last_assigned_dealer__c 
    AND (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    
    UNION ALL
    
    -- Recursive case: Select accounts where parentid matches the sfid of the previous level
    SELECT a.sfid, a.name, a.parentid, c.sfid AS cid, u.sfid AS uid,
           u.master_acct_id__c, u.accountid__c, u.dealeraccid__c, u.isagent__c, u.email, zcc.external_zip_code__c,
           ah.level + 1 AS level
    FROM salesforce.account a
    LEFT JOIN salesforce.contact c ON a.sfid = c.accountid
    LEFT JOIN salesforce."user" u ON u.contactid = c.sfid
    LEFT JOIN salesforce.zip_code__c zcc ON a.sfid = zcc.last_assigned_dealer__c
    AND (zcc.end_date__c IS NULL OR zcc.end_date__c >= CURRENT_DATE)
    INNER JOIN account_hierarchy ah ON a.parentid = ah.sfid   
),
dealer_hie AS (
    SELECT 
        ah.sfid, 
        ah.name, 
        ah.parentid,
        ah.email,
        ah.external_zip_code__c,  -- Only select necessary columns
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
                 AND ah.master_acct_id__c = ah.dealeraccid__c) THEN 'Master Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NOT NULL 
             AND ah.accountid__c = ah.dealeraccid__c 
             AND ah.accountid__c != ah.master_acct_id__c THEN 'Manager Dealer'
            WHEN LOWER(ah.isagent__c) = 'false' OR ah.isagent__c IS NULL
             AND ah.master_acct_id__c IS NULL 
             AND ah.accountid__c = ah.dealeraccid__c THEN 'Regional Dealer'
            WHEN LOWER(ah.isagent__c) = 'true' THEN 'Agent'
            ELSE 'Unknown'
        END AS dealer_type
    FROM account_hierarchy ah
)
SELECT count(*)
FROM dealer_hie 
WHERE dealer_type IN ('Manager Dealer', 'Regional Dealer');


