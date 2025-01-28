CREATE OR REPLACE FUNCTION public.get_state_code(p_zipcode character varying)
 RETURNS TABLE(state_code character varying)
 LANGUAGE plpgsql
AS $function$
DECLARE
    zipcode_arr VARCHAR[] := string_to_array(p_zipcode, '|');
BEGIN
    RETURN QUERY SELECT STATE__C as STATE_CD FROM salesforce."zip_code__c" WHERE "name" = ANY(zipcode_arr);
END;
$function$
;
