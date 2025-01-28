CREATE OR REPLACE FUNCTION public.update_last_modified_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
   NEW.last_modified_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$function$
;