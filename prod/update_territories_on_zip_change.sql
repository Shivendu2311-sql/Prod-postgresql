-- DROP FUNCTION public.update_territories_on_zip_change();

CREATE OR REPLACE FUNCTION public.update_territories_on_zip_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    old_last_assigned_dealer VARCHAR;
    zip_code TEXT;
    user_ids TEXT[];
    territories TEXT[];
BEGIN
    -- Capture the old value of last_assigned_dealer__c and the new zip code
    old_last_assigned_dealer := OLD.last_assigned_dealer__c;
    zip_code := NEW.zip_code__c;

    -- Fetch User IDs based on the old value of last_assigned_dealer__c
    SELECT ARRAY_AGG(sfid)
    INTO user_ids
    FROM salesforce."user" u
    WHERE contactid IN (
        SELECT sfid
        FROM salesforce.contact
        WHERE accountid = '0015c00002g0TodAAE'
        AND last_assigned_dealer__c = old_last_assigned_dealer
    );

    -- Retrieve assigned territories for these user IDs
    SELECT ARRAY_AGG(t.territory_id)  -- Replace territory_id with the actual column name
    INTO territories
    FROM "mapping"."Teams" t
    WHERE dealer_id = ANY(user_ids);

    -- Update isactive to false in the Territory table
    UPDATE "mapping"."Territory"
    SET isactive = false
    WHERE territory_id = ANY(territories)  -- Replace territory_id with the actual column name
    AND zip_code = zip_code;  -- Assuming zip_code is a column in the Territory table

    RETURN NEW;
END;
$function$
;
