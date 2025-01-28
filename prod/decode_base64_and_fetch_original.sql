-- DROP FUNCTION public.decode_base64_and_fetch_original(text);

CREATE OR REPLACE FUNCTION public.decode_base64_and_fetch_original(encoded_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    trimmed_id TEXT;
    padding_needed INT;
    base64_bytes BYTEA;
    unique_id_value TEXT;
    result_string TEXT;
BEGIN
    -- Trim '=' padding from the end of the string
    trimmed_id := rtrim(encoded_id, '=');

    -- Ensure the Base64 string has correct padding
    padding_needed := length(trimmed_id) % 4;
    IF padding_needed > 0 THEN
        trimmed_id := trimmed_id || repeat('=', 4 - padding_needed);
    END IF;

    -- Decode the Base64 string to binary data
    BEGIN
        base64_bytes := decode(trimmed_id, 'base64');
    EXCEPTION
        WHEN others THEN
            -- Log the issue and return NULL for invalid Base64
            RAISE NOTICE 'Invalid Base64 string: %', encoded_id;
            RETURN NULL;
    END;

    -- Convert binary data to hex string (unique ID)
    unique_id_value := encode(base64_bytes, 'hex');

    -- Retrieve the original string from the database
    SELECT e.original_string INTO result_string
    FROM pgadmin.encode_decode e
    WHERE e.unique_id = unique_id_value;

    -- If no match is found, return NULL
    IF result_string IS NULL THEN
        RAISE NOTICE 'No matching original string found for unique_id: %', unique_id_value;
        RETURN NULL;
    END IF;

    RETURN result_string;
END;
$function$
;
