CREATE OR REPLACE FUNCTION public.getancestor(inputchildid character varying)
 RETURNS TABLE(parentid character varying)
 LANGUAGE sql
AS $function$
WITH RECURSIVE Ancestors AS
        (
        SELECT  m.parentid, m.sfid
        FROM    salesforce."account" m
        WHERE   sfid = inputchildid
        UNION ALL
        SELECT  m.parentid, m.sfid
        FROM    Ancestors q
        JOIN    salesforce."account" m
        ON      m.sfid = q.parentid
        )
SELECT  sfid
FROM    Ancestors
WHERE   parentid IS NULL;
$function$
;
