CREATE OR REPLACE FUNCTION public.update_last_modified_date()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.last_modified_date = NOW();
    RETURN NEW;
END;
$function$
;
