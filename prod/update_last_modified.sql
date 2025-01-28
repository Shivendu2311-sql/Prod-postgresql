CREATE OR REPLACE FUNCTION public.update_last_modified()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Set both date and time
    NEW.last_modified_date = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$
;
