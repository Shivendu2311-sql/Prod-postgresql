CREATE OR REPLACE FUNCTION public.get_agent_info_new(p_dealer_id text, p_user_id text)
 RETURNS TABLE(agent_info json)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY SELECT json_build_object('NAME', json_agg(u.NAME), 'SFID',  json_agg(u.SFID)) FROM salesforce."user" u WHERE accountid = p_dealer_id  AND sfid != p_user_id AND LOWER(isagent__c) = 'true';
END;$function$
;