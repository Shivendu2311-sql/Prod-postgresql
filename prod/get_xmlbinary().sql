CREATE OR REPLACE FUNCTION public.get_xmlbinary()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
                    DECLARE
                      xmlbin varchar;
                    BEGIN
                      select into xmlbin setting from pg_settings where name='xmlbinary';
                      RETURN xmlbin;
                    END;
                 $function$
;
