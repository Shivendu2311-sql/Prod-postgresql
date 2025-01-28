CREATE OR REPLACE FUNCTION public.getdescendants(inputparentid character varying)
 RETURNS TABLE(parentid character varying, childid character varying, generation numeric)
 LANGUAGE sql
AS $function$
  with  RECURSIVE
descendants
  (parentid, descendant, lvl) 
as
  ( select parentid, sfid, 1
    from salesforce."account"
  union all
    select d.parentid, s.sfid, d.lvl + 1
    from descendants  d
      join salesforce."account"  s
        on d.descendant = s.parentid
  ) 
select *
from descendants 
where parentid = inputParentId
order by parentid, lvl, descendant;
$function$
;
