-- DROP PROCEDURE public.zipaggregation();

CREATE OR REPLACE PROCEDURE public.zipaggregation()
 LANGUAGE plpgsql
AS $procedure$
BEGIN

	--Total Workable Leads
	INSERT INTO pgadmin."Zipcode" (zipcode, tlm__c, region__c, vgpm_market__c, sfdc_division, dma__c, sub_market__c, city__c, state__c, primary_broadband_provider__c , primary_broadband_providermax_speed__c, total_workable_leads)
	SELECT k.ZIPCODE, k.tlm__c, k.region__c, k.vgpm_market__c, k.sfdc_division, k.dma__c, k.sub_market__c, k.city__c, k.state__c, k.primary_broadband_provider__c , k.primary_broadband_providermax_speed__c, coalesce(a.do_not_knock, 0) FROM
	(SELECT d.zipcode as ZIPCODE, COUNT(1) as do_not_knock
    FROM pgadmin."Prospect_partition" c RIGHT OUTER JOIN
	pgadmin."ZipcodeInit" d
	ON c.zip_cd = d.zipcode
    WHERE c.uv_variable_1 = 'Y'
	GROUP BY d.zipcode) a RIGHT OUTER JOIN pgadmin."ZipcodeInit" k
    ON a.zipcode = k.zipcode
    GROUP BY k.zipcode, coalesce(a.do_not_knock, 0);
	
	--Total MDU, NO SPEED, MEDHIGH SPEED, EE LEADS
	UPDATE pgadmin."Zipcode" a
	SET total_mdu = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" e
	WHERE (((unit_designator_cd = '') IS NOT TRUE) OR ((unit_nbr = '') IS NOT TRUE))
	AND e.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
	total_no_speed = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE COALESCE(hsia_qftn_speed_val , 0) = 0 
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
	total_med_high_speed = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val > 2500 AND hsia_qftn_speed_val < 7500
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
	total_ee_leads = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE lang_desc = 'Spanish'
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
	total_estimated_hc = total_workable_leads/(26*40*4),
    total_50m_workable = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val = 50
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
    total_new_wireless_opp = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE phn_type_cd = 'W'
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
    total_fiber_1g_5g = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val > 1000 AND hsia_qftn_speed_val < 5000
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
    total_100m = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val = 100
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
    total_1g = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val = 1000
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0),
    total_5g = COALESCE((SELECT COUNT(1) FROM pgadmin."Prospect_partition" f
	WHERE hsia_qftn_speed_val = 5000
	AND f.zip_cd = a.zipcode
	GROUP BY zip_cd), 0);
    
    UPDATE pgadmin."Zipcode" b
    SET total_sfu = total_workable_leads - total_mdu,
    total_ee_leads_perc = COALESCE(ROUND(((Total_ee_leads/NULLIF(total_workable_leads, 0))*100), 2), 0),
    total_estimated_hc_50 = total_50m_workable/(26*40*4);
    
    UPDATE pgadmin."Zipcode" b
    SET total_sfu_perc = COALESCE(ROUND(((total_sfu/NULLIF(total_workable_leads, 0))*100), 2), 0);
	
END;$procedure$
;
