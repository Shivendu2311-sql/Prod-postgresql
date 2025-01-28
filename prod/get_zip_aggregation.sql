-- DROP FUNCTION public.get_zip_aggregation(varchar);

CREATE OR REPLACE FUNCTION public.get_zip_aggregation(p_zipcode character varying)
 RETURNS TABLE(total_assigned_leads text, total_fiber_all text, total_bb text, total_25m_plus text, total_new_wireless_opportunities text, total_sfu text, total_mdu text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    --zipcode_arr VARCHAR[] := string_to_array(p_zipcode, '|');
    loop_count integer := array_length(string_to_array(p_zipcode, '|'), 1);
    zipcode text;
    attribute_filter text;
    query_builder text;
BEGIN

    zipcode := SPLIT_PART(p_zipcode, '|', 1);
    SELECT attribute_filter__c
    INTO attribute_filter
    FROM salesforce."zip_code__c"
    WHERE name = zipcode;
    query_builder := concat(' ((zip_cd = ', E'\'', zipcode, E'\'', ' ', attribute_filter, ')');
    --RAISE NOTICE 'LOOP_COUNT: %', loop_count;
    for count in 2..loop_count loop
        RAISE NOTICE 'COUNT: %', count;
        zipcode := SPLIT_PART(p_zipcode, '|', count);
        SELECT attribute_filter__c
        INTO attribute_filter
        FROM salesforce."zip_code__c"
        WHERE name = zipcode;
        query_builder := concat(query_builder, ' OR (zip_cd = ', E'\'', zipcode, E'\'', ' ', attribute_filter, ')');
    END LOOP;
    --RAISE NOTICE 'Value: %', query_builder;
    query_builder := concat('SELECT 
        TO_CHAR(COUNT(1), ''FM999,999,999'') total_assigned_leads,
        TO_CHAR(SUM(CASE WHEN hsia_qftn_speed_val >= 1000 AND hsia_qftn_speed_val <= 5000 AND (df_curr_internet NOT IN (''300m300mg'', ''500m100mg'', ''500m500mg'', ''1000m200mg'',''1000m1000mg'', ''2000m2000mg'', ''Hsia500g'', ''Hsia500a'', ''Hsia2000g'', ''300'', ''1000'', ''Hsia5000g'', ''300m75mg'', ''5000m5000mg'') OR COALESCE(df_curr_internet, ''0'') = ''0'' OR df_curr_internet= '''') THEN 1 ELSE 0 END), ''FM999,999,999'') AS total_assigned_fiber,
        TO_CHAR(SUM(CASE WHEN df_curr_internet NOT IN (''300m300mg'', ''500m100mg'', ''500m500mg'', ''1000m200mg'', ''1000m1000mg'', ''2000m2000mg'', ''Hsia500g'', ''Hsia500a'', ''Hsia2000g'', ''300'', ''1000'', ''Hsia5000g'', ''300m75mg'', ''5000m5000mg'') AND hsia_qftn_speed_val >= 1000 THEN 1 ELSE 0 END), ''FM999,999,999'') AS total_bb,
        TO_CHAR(SUM(CASE WHEN hsia_qftn_speed_val >= 25 THEN 1 ELSE 0 END), ''FM999,999,999'') AS total_25m_plus,
        TO_CHAR(SUM(CASE WHEN pstpd_wrls_subsrptn_sts_cd = ''A'' THEN 1 ELSE 0 END), ''FM999,999,999'') AS total_new_wireless_opp,
        TO_CHAR(SUM(CASE WHEN (unit_designator_cd IS NULL or unit_designator_cd='''') AND (unit_nbr IS NULL or unit_nbr='''') THEN 1 ELSE 0 END), ''FM999,999,999'') AS TOTAL_SFU,
        TO_CHAR(SUM(CASE WHEN (unit_designator_cd IS NOT NULL AND unit_designator_cd != '''') OR (unit_nbr IS NOT NULL AND unit_nbr != '''') THEN 1 ELSE 0 END), ''FM999,999,999'') AS TOTAL_MDU
       FROM pgadmin."Prospect_partition" p
    WHERE uv_variable_1 = ''Y''
    AND isscrubbed = false
    AND ', query_builder, ')');
    --RAISE NOTICE 'Value: %', query_builder;
    --EXECUTE FORMAT(query_builder);
    RETURN QUERY EXECUTE FORMAT(query_builder);
END;
$function$
;
