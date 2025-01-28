CREATE OR REPLACE FUNCTION public.get_aloc_aggregation(p_aloc character varying)
 RETURNS TABLE(total_assigned_leads text, total_fiber_all text, total_bb text, total_25m_plus text, total_new_wireless_opportunities text, total_sfu text, total_mdu text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    aloc_arr VARCHAR[] := string_to_array(p_aloc, '|');
BEGIN
    RETURN QUERY SELECT 
       TO_CHAR(COUNT(1), 'FM999,999,999') total_workable_leads,
       TO_CHAR(SUM(CASE WHEN hsia_qftn_speed_val >= 1000 AND hsia_qftn_speed_val <= 5000 AND (df_curr_internet NOT IN ('300m300mg', '500m100mg', '500m500mg', '1000m200mg','1000m1000mg', '2000m2000mg', 'Hsia500g', 'Hsia500a', 'Hsia2000g', '300', '1000', 'Hsia5000g', '300m75mg', '5000m5000mg') OR COALESCE(df_curr_internet, '0') = '0' OR df_curr_internet= '') THEN 1 ELSE 0 END), 'FM999,999,999') AS total_fiber_1g_5g,
       TO_CHAR(SUM(CASE WHEN df_curr_internet NOT IN ('300m300mg', '500m100mg', '500m500mg', '1000m200mg', '1000m1000mg', '2000m2000mg', 'Hsia500g', 'Hsia500a', 'Hsia2000g', '300', '1000', 'Hsia5000g', '300m75mg', '5000m5000mg') AND hsia_qftn_speed_val >= 1000 THEN 1 ELSE 0 END), 'FM999,999,999') AS total_bb,
       TO_CHAR(SUM(CASE WHEN hsia_qftn_speed_val >= 25 THEN 1 ELSE 0 END), 'FM999,999,999') AS total_25m_plus,
       TO_CHAR(SUM(CASE WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 1 ELSE 0 END), 'FM999,999,999') AS total_new_wireless_opp,
       TO_CHAR(SUM(CASE WHEN (unit_designator_cd isnull or unit_designator_cd='') AND (unit_nbr isnull or unit_nbr='') THEN 1 ELSE 0 END), 'FM999,999,999') AS TOTAL_SFU,
       TO_CHAR(SUM(CASE WHEN (unit_designator_cd IS NOT NULL AND unit_designator_cd != '') OR (unit_nbr IS NOT NULL AND unit_nbr != '') THEN 1 ELSE 0 END), 'FM999,999,999') AS TOTAL_MDU
       FROM pgadmin."Prospect" p
WHERE 
-- uv_variable_1 = 'Y'
-- AND isscrubbed = false
-- AND
p.audience_id = ANY(aloc_arr);
END;
$function$
;


-- Find functions explicitly used in the database
-- Find functions used in triggers and their definitions
SELECT 
    p.proname AS function_name,
    p.proargtypes AS argument_types,
    t.tgname AS trigger_name,
    t.tgtype AS trigger_type,*
FROM 
    pg_proc p
JOIN 
    pg_trigger t ON t.tgfoid = p.oid  -- join functions to triggers by tgfoid
JOIN 
    pg_class c ON c.oid = t.tgrelid  -- join triggers to the tables they are associated with
WHERE 
    t.tgisinternal = false  -- only consider user-defined triggers, not system ones
ORDER BY 
    function_name, trigger_name;

-- Find functions called explicitly and via triggers
-- Find functions called explicitly and via triggers
WITH function_usage AS (
    -- Find functions called in triggers
    SELECT 
        p.proname AS function_name,
        p.proargtypes AS argument_types,
        t.tgname AS trigger_name,
        'trigger' AS usage_type
    FROM 
        pg_proc p
    JOIN 
        pg_trigger t ON t.tgfoid = p.oid  -- join functions to triggers by tgfoid
    WHERE 
        t.tgisinternal = false  -- only consider user-defined triggers, not system ones

    UNION ALL

    -- Find functions used in views (or other database objects)
    SELECT 
        p.proname AS function_name,
        p.proargtypes AS argument_types,
        v.viewname AS object_name,
        'view' AS usage_type
    FROM 
        pg_proc p
    JOIN 
        pg_depend d ON p.oid = d.objid  -- join function dependencies to other objects
    JOIN 
        pg_class c ON c.oid = d.refobjid  -- this connects function usage to views, tables, etc.
    JOIN 
        pg_views v ON v.oid = c.oid  -- filtering for views
    WHERE 
        c.relkind = 'v'  -- ensure it's a view
)
SELECT * 
FROM function_usage
ORDER BY function_name, object_name;
