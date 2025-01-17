-- get_icon_color_json

-- DROP FUNCTION public.get_icon_color_json(json);

CREATE OR REPLACE FUNCTION public.get_icon_color_json(p_input_json json)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_audience_id text;          -- Variable to store the extracted audience_id
    v_icon_output text;          -- The icon value to be inserted as a string
    query_builder text;          -- Dynamic SQL query builder
    rec jsonb;                   -- JSON record from the input array
    v_json_array jsonb := '[]'::jsonb;  -- To store the modified JSON array
    v_state_cd text;             -- To store the extracted state_cd
BEGIN
    -- Loop through each element in the JSON array
    FOR rec IN 
        SELECT * FROM jsonb_array_elements(p_input_json::jsonb) AS records
    LOOP
        -- Extract the 28th value (index 27 in zero-based indexing) as audience_id
        v_audience_id := rec->>27;

        -- Handle case where audience_id is NULL or empty
        IF v_audience_id IS NULL OR v_audience_id = '' THEN
            v_audience_id := 'default_audience_id';  -- Set default or fallback value
        END IF;

        -- Extract the 14th value (index 13 in zero-based indexing) as state_cd
        v_state_cd := rec->>14;

        -- Handle case where state_cd is NULL or empty
        IF v_state_cd IS NULL OR v_state_cd = '' THEN
            v_state_cd := 'default_state_cd';  -- Set default or fallback value if needed
        END IF;

        -- Construct the dynamic query to get the icon(s) based on audience_id and state_cd
        query_builder := format('
            SELECT m.icon_api AS icon_output
            FROM pgadmin."Prospect_partition" p
            INNER JOIN salesforce."zip_code__c" z ON p.zip_cd = z.name  
            INNER JOIN pgadmin."map_link_table" m ON
                (CASE
                    WHEN ((p.unit_designator_cd IS NOT NULL AND p.unit_designator_cd != '''') OR
                          (p.unit_nbr IS NOT NULL AND p.unit_nbr != '''')) AND
                         (p.unit_designator_cd != ''UNDEFINED'' AND p.unit_nbr != ''UNDEFINED'') THEN
                         CASE
                             WHEN p.isfiber = true THEN ''mdu_fiber1'' 
                             WHEN p.pstpd_wrls_subsrptn_sts_cd = ''A'' THEN ''mdu_wireless1''
                             ELSE ''mdu''
                         END
                    ELSE
                         CASE
                             WHEN p.isfiber = true THEN ''sfu_fiber1'' 
                             WHEN p.pstpd_wrls_subsrptn_sts_cd = ''A'' THEN ''sfu_wireless1''
                             ELSE ''sfu''
                         END
                END) = m.identifier
            WHERE p.audience_id = %L
            AND p.state_cd = %L
            LIMIT 1', v_audience_id, v_state_cd);

        -- Execute the query to get the icon
        EXECUTE query_builder INTO v_icon_output;

        -- If no icon is found, set a default icon
        IF v_icon_output IS NULL OR v_icon_output = '' THEN
            v_icon_output := 'https://example.com/default_icon.png'; -- Default icon URL
        END IF;

        -- Add the icon as the 44th element (index 43) of the current record
        rec := rec || to_jsonb(v_icon_output);

        -- Add the modified record to the final JSON array
        v_json_array := v_json_array || jsonb_build_array(rec);
    END LOOP;

    -- Return the modified JSON array
    RETURN v_json_array;
END;
$function$
;
