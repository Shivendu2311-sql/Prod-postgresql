-- DROP FUNCTION public.get_icon_color(varchar, text);

CREATE OR REPLACE FUNCTION public.get_icon_color(p_zipcode character varying, attribute_filter text)
 RETURNS TABLE(zipcode_json_output json)
 LANGUAGE plpgsql
AS $function$
DECLARE
    query_builder text := get_query_builder(p_zipcode, attribute_filter);
BEGIN
    query_builder := CONCAT('SELECT json_build_object(''AUD'', json_agg(audience_id),''LAT'', json_agg(uv_variable_4),''LON'', json_agg(uv_variable_5), ''ICON'', json_agg(m.icon_api))
    FROM pgadmin."Prospect_partition" p INNER JOIN salesforce."zip_code__c" z 
    ON p.zip_cd = z.name 
    INNER JOIN pgadmin."map_link_table" m ON 
    (CASE 
        WHEN ((unit_designator_cd IS NOT NULL AND unit_designator_cd != '''') OR (unit_nbr IS NOT NULL AND unit_nbr != '''')) AND (unit_designator_cd != ''UNDEFINED'' AND unit_nbr != ''UNDEFINED'') THEN 
            CASE 
                WHEN isfiber = true THEN ''mdu_fiber'' 
                WHEN pstpd_wrls_subsrptn_sts_cd = ''A'' THEN ''mdu_wireless''
                ELSE ''mdu''
            END
        ELSE
            CASE
                WHEN isfiber = true THEN ''sfu_fiber'' 
                WHEN pstpd_wrls_subsrptn_sts_cd = ''A'' THEN ''sfu_wireless''
                ELSE ''sfu''
            END
     END) = m.identifier
     AND ISSCRUBBED = false
     AND UV_VARIABLE_1 = ''Y'' 
     AND ', query_builder);

    RETURN QUERY EXECUTE FORMAT(query_builder);
END; 
$function$
;
