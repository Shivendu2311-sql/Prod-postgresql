CREATE OR REPLACE FUNCTION public.get_query_builder(p_zipcode character varying)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
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

    for count in 2..loop_count loop
        RAISE NOTICE 'COUNT: %', count;
        zipcode := SPLIT_PART(p_zipcode, '|', count);
        SELECT attribute_filter__c
        INTO attribute_filter
        FROM salesforce."zip_code__c"
        WHERE name = zipcode;
        query_builder := concat(query_builder, ' OR (zip_cd = ', E'\'', zipcode, E'\'', ' ', attribute_filter, ')');
    END LOOP;
    query_builder := concat(query_builder, ')');
    --RAISE NOTICE 'Value: %', query_builder;
    RETURN query_builder;
END;
$function$
;
