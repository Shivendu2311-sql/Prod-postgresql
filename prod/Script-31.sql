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
)
select * from account_hierarchy

--CREATE MATERIALIZED VIEW mv_filtered_zip_code AS
--SELECT *
--FROM salesforce.zip_code__c
--WHERE end_date__c IS NULL OR end_date__c >= CURRENT_DATE;