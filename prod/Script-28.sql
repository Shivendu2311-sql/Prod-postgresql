SELECT json_agg(result)
FROM public.get_manager_dealer_data('0018b000025j7XSAAY', '2025-01-01', '2025-01-21')AS result;



[{"sfid":"0015c00002eT05NAAS","name":"Adventure Dealer","zip_codes":"01002, 01013, 01022, 01030, 01031, 01033, 01034, 01035, 01039, 01057, 49037, 76065","zip_code_count":12,"total_lead_count":29291,"sales_conversion_count":1466,"comeback_count":946,"to_be_visited_count":1338,"do_not_knock_count":1035,"total_pending_disposition":72416}, 
 {"sfid":"0018b0000225L0DAAU","name":"Test Dealer Shawnee1","zip_codes":"01001, 01002, 01008, 01010, 01011, 01013, 01022, 01030, 01068, 76010","zip_code_count":10,"total_lead_count":2242,"sales_conversion_count":110,"comeback_count":83,"to_be_visited_count":67,"do_not_knock_count":131,"total_pending_disposition":7055}, 
 {"sfid":"0018b0000225O51AAE","name":"Test Account Shawnee","zip_codes":"76065","zip_code_count":1,"total_lead_count":342,"sales_conversion_count":5,"comeback_count":3,"to_be_visited_count":2,"do_not_knock_count":1,"total_pending_disposition":340}, 
 {"sfid":"001WG00000Eo3ayYAB","name":"Dummy Dealer 2","zip_codes":"76065","zip_code_count":1,"total_lead_count":342,"sales_conversion_count":10,"comeback_count":6,"to_be_visited_count":4,"do_not_knock_count":2,"total_pending_disposition":680}]
 
 [{"sfid":"0015c00002eT05NAAS","name":"Adventure Dealer","zip_codes":"01002, 01013, 01022, 01030, 01031, 01033, 01034, 01035, 01039, 01057, 49037, 76065","zip_code_count":12,"total_lead_count":29291,"sales_conversion_count":1466,"comeback_count":946,"to_be_visited_count":1338,"do_not_knock_count":1035,"total_pending_disposition":72416}, 
 {"sfid":"001WG00000Eo3ayYAB","name":"Dummy Dealer 2","zip_codes":"76065","zip_code_count":1,"total_lead_count":342,"sales_conversion_count":10,"comeback_count":6,"to_be_visited_count":4,"do_not_knock_count":2,"total_pending_disposition":680}]
 
 WITH matching_audience_ids AS (
    SELECT
        p.audience_id,
        ld.txt_audience_id,
        ld.txt_lead_disposition,
        t.territory_id
    FROM
        pgadmin."Prospect_partition" p
    JOIN
        mapping."Territory" t ON p.zip_cd = t.zip_cd 
    JOIN
        territory_geometries tg ON tg.territory_id = t.territory_id AND t.expiration_date >= CURRENT_DATE AND t.isactive IS NOT FALSE 
    LEFT JOIN
        latest_dispositions ld
        ON p.audience_id = ld.txt_audience_id AND ld.rn = 1
    JOIN
        mapping."Teams" tm ON tm.territory_id = t.territory_id
    WHERE 
        ld.txt_lead_disposition IS NOT NULL
        AND tm.agent_id = get_lead_counts_nds_2.agent_id  
        AND ST_Contains(
            tg.geom,
            ST_SetSRID(ST_MakePoint(p.uv_variable_5::NUMERIC, p.uv_variable_4::NUMERIC), 4326)
        ) 
        AND (
            CASE 
                WHEN (
                    ((unit_designator_cd IS NOT NULL AND unit_designator_cd != '') OR (unit_nbr IS NOT NULL AND unit_nbr != ''))
                    AND (unit_designator_cd != 'UNDEFINED' AND unit_nbr != 'UNDEFINED')
                )
                THEN
                    CASE
                        WHEN isfiber = true THEN 'fiber'
                        WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'wireless'
                        ELSE 'other'
                    END
                ELSE
                    CASE
                        WHEN isfiber = true THEN 'fiber'
                        WHEN pstpd_wrls_subsrptn_sts_cd = 'A' THEN 'wireless'
                        ELSE 'other'
                    END
            END = p_lead_type -- Compare against the parameter
            OR p_lead_type = 'all'
        )
        AND EXISTS (
            SELECT 1 
            FROM CombinedFilters cf 
            WHERE cf.combined_filter IS NOT NULL 
              AND (cf.combined_filter)::text LIKE '%' || quote_literal(t.zip_cd) || '%'
        ) 
        AND (p_territory_ids IS NULL OR t.territory_id = ANY(p_territory_ids))
)
SELECT
    COUNT(DISTINCT audience_id),
    COUNT(*) FILTER (WHERE txt_lead_disposition IN ('Internet Only Sale', 'Wireless Only Sale', 'Wireless and Internet Sale')),
    COUNT(*) FILTER (WHERE txt_lead_disposition IN ('Decision Maker Not Home', 'No Answer')),
    COUNT(*) FILTER (WHERE txt_lead_disposition = 'Follow up Appointment'),
    COUNT(*) FILTER (WHERE txt_lead_disposition IN (
            'Decision Maker Not Home - Final', 'No Answer - Final', 'Competitor Loyalty', 'Discount Requested', 'Employee/Retiree',
            'Existing Customer', 'Health Concern', 'Installation Timing', 'Language Barrier - Spanish', 'Language Barrier - Other',
            'Moving', 'Not Interested', 'Not Qualified', 'Plan Limitations', 'Price Sensitivity', 'Under Contract',
            'ACC Bulk', 'Apartment/Condo', 'Business', 'Data Discrepancy', 'Deceased', 'Disaster', 'Do Not Knock Request',
            'Gated', 'Marina', 'Military Base', 'New Build', 'No Access', 'Restricted Area', 'Safety', 'Seasonal',
            'Senior Living/Convalescent Center', 'Student Housing/Dorm''s', 'Vacant- Lot'
        ))
INTO
    total_lead_count,
    sales_conversion_count,
    comeback_count,
    to_be_visited_count,
    do_not_knock_count
FROM
    matching_audience_ids
WHERE
    (ld.last_modified_date IS NULL 
     OR (ld.last_modified_date BETWEEN start_date AND end_date)) -- Use last_modified_date for other conditions
;
