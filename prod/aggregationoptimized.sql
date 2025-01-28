-- DROP PROCEDURE public.aggregationoptimized();

CREATE OR REPLACE PROCEDURE public.aggregationoptimized()
 LANGUAGE plpgsql
AS $procedure$
BEGIN

--Refresh data
--TRUNCATE TABLE pgadmin."zipAggregationTable";
    
UPDATE pgadmin."Zipcode"
SET total_estimated_hc = 0,
    total_workable_leads = 0,
    total_estimated_hc_50 = 0,
    total_50m_workable = 0,
    total_mdu = 0,
    total_sfu = 0,
    total_sfu_perc = 0,
    total_no_speed = 0,
    total_med_high_speed = 0,
    total_fiber_1g_5g = 0,
    total_100m = 0,
    total_1g = 0,
    total_5g = 0,
    total_ee_leads = 0,
    total_ee_leads_perc = 0,
    total_new_wireless_opp = 0;    


INSERT INTO pgadmin."zipAggregationTable" (zipcode, total_workable_leads, TOTAL_SFU, TOTAL_NO_SPEED, TOTAL_MED_HIGH_SPEED, total_ee_leads, total_50m_workable, total_new_wireless_opp, total_fiber_1g_5g, total_100m, total_1g, total_5g)
 SELECT ZIP_CD, 
        SUM(CASE WHEN uv_variable_1 = 'Y' THEN 1 ELSE 0 END) total_workable_leads,
        COUNT((unit_designator_cd = '') AND (unit_designator_cd = '')) AS TOTAL_SFU, 
        SUM(CASE WHEN hsia_qftn_speed_val = 0 THEN 1 ELSE 0 END) AS TOTAL_NO_SPEED,
        SUM(CASE WHEN hsia_qftn_speed_val > 2500 AND hsia_qftn_speed_val < 7500 THEN 1 ELSE 0 END) AS TOTAL_MED_HIGH_SPEED,
        SUM(CASE WHEN lang_desc = 'Spanish' THEN 1 ELSE 0 END) AS total_ee_leads,
        SUM(CASE WHEN hsia_qftn_speed_val = 50 THEN 1 ELSE 0 END) AS total_50m_workable,
        SUM(CASE WHEN phn_type_cd = 'W' THEN 1 ELSE 0 END) AS total_new_wireless_opp,
        SUM(CASE WHEN hsia_qftn_speed_val > 1000 AND hsia_qftn_speed_val < 5000 THEN 1 ELSE 0 END) AS total_fiber_1g_5g,
        SUM(CASE WHEN hsia_qftn_speed_val = 100 THEN 1 ELSE 0 END) AS total_100m,
        SUM(CASE WHEN hsia_qftn_speed_val = 1000 THEN 1 ELSE 0 END) AS total_1g,
        SUM(CASE WHEN hsia_qftn_speed_val = 5000 THEN 1 ELSE 0 END) AS total_5g
 FROM pgadmin."Prospect_partition" 
 GROUP BY ZIP_CD;
 
UPDATE pgadmin."zipAggregationTable"
SET total_mdu= total_workable_leads - total_sfu,
    total_ee_leads_perc = COALESCE(ROUND(((Total_ee_leads/NULLIF(total_workable_leads, 0))*100), 2), 0),
    total_estimated_hc_50 = total_50m_workable/(26*40*4),
    total_estimated_hc =  total_workable_leads/(26*40*4),
    total_sfu_perc = COALESCE(ROUND(((total_sfu/NULLIF(total_workable_leads, 0))*100), 2), 0);
  
UPDATE pgadmin."Zipcode"
SET total_estimated_hc = x.total_estimated_hc,
    total_workable_leads = x.total_workable_leads,
    total_estimated_hc_50 = x.total_estimated_hc_50,
    total_50m_workable = x.total_50m_workable,
    total_mdu = x.total_mdu,
    total_sfu = x.total_sfu,
    total_sfu_perc = x.total_sfu_perc,
    total_no_speed = x.total_no_speed,
    total_med_high_speed = x.total_med_high_speed,
    total_fiber_1g_5g = x.total_fiber_1g_5g,
    total_100m = x.total_100m,
    total_1g = x.total_1g,
    total_5g = x.total_5g,
    total_ee_leads = x.total_ee_leads,
    total_ee_leads_perc = x.total_ee_leads_perc,
    total_new_wireless_opp = x.total_new_wireless_opp
FROM (
    SELECT k.zipcode,
        k.total_workable_leads, 
        k.TOTAL_SFU, 
        k.total_no_speed, 
        k.TOTAL_MED_HIGH_SPEED, 
        k.total_ee_leads, 
        k.total_50m_workable, 
        k.total_new_wireless_opp, 
        k.total_fiber_1g_5g, 
        k.total_100m, 
        k.total_1g, 
        k.total_5g, 
        k.total_mdu, 
        k.total_ee_leads_perc, 
        k.total_estimated_hc_50, 
        k.total_estimated_hc, 
        k.total_sfu_perc
 FROM pgadmin."zipAggregationTable" k 
 LEFT OUTER JOIN pgadmin."Zipcode" z
 ON k.zipcode = z.zipcode
    ) AS x
 WHERE x.zipcode = pgadmin."Zipcode".zipcode;
    
END;$procedure$
;
