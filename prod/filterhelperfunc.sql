-- DROP FUNCTION public.filterhelperfunc();

CREATE OR REPLACE FUNCTION public.filterhelperfunc()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
  
    IF (new.acc_con_cmnty_ind = 'Y') THEN
        new.isacc = true;
    ELSIF (new.acc_con_cmnty_ind = 'N') THEN
        new.isacc = false;
    END IF;
    
    IF ((new.unit_designator_cd IS NULL OR new.unit_designator_cd = '') 
        AND (new.unit_nbr IS NULL OR new.unit_nbr = '')) 
        OR (new.unit_designator_cd = 'UNDEFINED' OR new.unit_nbr = 'UNDEFINED') THEN
        new.ismdu = false;
    ELSE
        new.ismdu = true;
    END IF;
    
    IF (new.uv_variable_18 > '1901-01-01' 
        AND new.hsia_qftn_speed_val >= 1000 
        AND new.hsia_qftn_speed_val <= 5000 
        AND (new.df_curr_internet NOT IN 
            ('300m300mg', '500m100mg', '500m500mg', '1000m200mg', '1000m1000mg', 
             '2000m2000mg', 'Hsia500g', 'Hsia500a', 'Hsia2000g', '300', '1000', 
             'Hsia5000g', '300m75mg', '5000m5000mg') 
            OR COALESCE(new.df_curr_internet, '0') = '0' OR new.df_curr_internet= '' )) THEN
        new.isfiber = true;
    ELSE
        new.isfiber = false;
    END IF;
    
    IF (new.pstpd_wrls_subsrptn_sts_cd = 'A' OR new.wirelessoppcorrection = true) THEN
        new.iswireless = true;
    ELSE
        new.iswireless = false;
    END IF;
    
    IF (new.isfiber = true OR new.iswireless = true) THEN
        new.isscrubbed = false;
    ELSE 
        new.isscrubbed = true;
    END IF;
        
    new.psa = COALESCE(new.zip_cd, '') || COALESCE(new.clli_cd, '') || COALESCE(new.dstrb_area_cd, '');
    new.updated_by_trigger = true;
    
    RETURN NEW;
  
END;
$function$
;
