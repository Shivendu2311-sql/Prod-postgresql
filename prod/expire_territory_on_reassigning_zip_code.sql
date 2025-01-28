CREATE OR REPLACE FUNCTION public.expire_territory_on_reassigning_zip_code()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE "mapping"."Territory" tr
    SET isactive = false
    WHERE tr.territory_id IN (
        SELECT t.territory_id
        FROM "mapping"."Teams" t
        JOIN salesforce.user u ON t.dealer_id = u.sfid
        JOIN salesforce.contact c ON u.contactid = c.sfid
        WHERE c.accountid = OLD.last_assigned_dealer__c
		AND zip_cd = OLD.external_zip_code__c
    );
    
    RETURN NEW;
END;
$function$
;
