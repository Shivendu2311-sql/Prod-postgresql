CREATE OR REPLACE FUNCTION public.leadassignmentcount()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$DECLARE
    total_assigned_count integer := 0;
    total_zipcode_count integer := 0;
	total_assigned_fiber integer := 0;
BEGIN
	EXECUTE FORMAT('SELECT COUNT(1) FROM pgadmin."Prospect_partition" WHERE uv_variable_1 = ''Y'' AND ISSCRUBBED = false AND zip_cd = %1$L', old.name) INTO total_zipcode_count;
    IF new.last_assigned_dealer__c IS NOT NULL THEN
        EXECUTE FORMAT('SELECT COUNT(1) FROM pgadmin."Prospect_partition" WHERE uv_variable_1 = ''Y'' AND ISSCRUBBED = false AND zip_cd = %1$L %2$s', old.name, new.attribute_filter__c) INTO total_assigned_count;
        --EXECUTE FORMAT('SELECT COUNT(1) FROM pgadmin."Prospect" WHERE uv_variable_1 = ''Y'' AND ISSCRUBBED = false AND zip_cd = %1$L', old.name) INTO total_zipcode_count;
        EXECUTE FORMAT('SELECT COUNT(1) FROM pgadmin."Prospect_partition" WHERE uv_variable_1 = ''Y'' AND ISSCRUBBED = false AND isfiber = true AND zip_cd = %1$L %2$s', old.name, new.attribute_filter__c) INTO total_assigned_fiber;
		new.total_assigned_leads__c = total_assigned_count;
        new.total_assigned_gap__c = total_zipcode_count - total_assigned_count;
		new.total_assigned_fiber__c = total_assigned_fiber;
    ELSIF new.last_assigned_dealer__c ISNULL THEN
        new.total_assigned_leads__c = 0;
        new.total_assigned_gap__c = total_zipcode_count;
    END IF;
    RETURN NEW;
END;$function$
;
