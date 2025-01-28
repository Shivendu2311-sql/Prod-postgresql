CREATE OR REPLACE FUNCTION public.update_injection_date()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.injection_date = NOW();
    RETURN NEW;
END;
$function$
;
