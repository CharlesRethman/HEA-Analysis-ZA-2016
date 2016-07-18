BEGIN;

ALTER TABLE zaf.veg_cond_idx_1512 DROP COLUMN IF EXISTS vci_num;
ALTER TABLE zaf.veg_cond_idx_1512 DROP COLUMN IF EXISTS vci;
ALTER TABLE zaf.veg_cond_idx_1601 DROP COLUMN IF EXISTS vci_num;
ALTER TABLE zaf.veg_cond_idx_1601 DROP COLUMN IF EXISTS vci;
ALTER TABLE zaf.ag_stress_idx_16013 DROP COLUMN IF EXISTS asi_num;
ALTER TABLE zaf.ag_stress_idx_16013 DROP COLUMN IF EXISTS asi;

ALTER TABLE zaf.veg_cond_idx_1512 RENAME COLUMN vci TO vci_gs;
ALTER TABLE zaf.ag_stress_idx_16013 RENAME COLUMN asi TO asi_gs;

ALTER TABLE zaf.veg_cond_idx_1512 ADD COLUMN vci_num NUMERIC;
ALTER TABLE zaf.veg_cond_idx_1512 ADD COLUMN vci VARCHAR(15);
ALTER TABLE zaf.veg_cond_idx_1601 ADD COLUMN vci_num NUMERIC;
ALTER TABLE zaf.veg_cond_idx_1601 ADD COLUMN vci VARCHAR(15);
ALTER TABLE zaf.ag_stress_idx_16013 ADD COLUMN asi_num INTEGER;
ALTER TABLE zaf.ag_stress_idx_16013 ADD COLUMN asi VARCHAR(15);

COMMIT;


BEGIN;

UPDATE zaf.ag_stress_idx_16013 SET asi_num = 85, asi = '>= 85' WHERE asi_gs > 39 AND asi_gs < 80;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 70, asi = '70 - 85' WHERE asi_gs > 80 AND asi_gs < 100;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 55, asi = '55 - 70' WHERE asi_gs > 130 AND asi_gs < 150;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 40, asi = '40 - 55' WHERE asi_gs > 180 AND asi_gs < 195;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 25, asi = '25 - 40' WHERE asi_gs > 230 AND asi_gs < 250;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 10, asi = '10 - 25' WHERE asi_gs > 195 AND asi_gs < 202;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 1, asi = '< 10' WHERE asi_gs > 150 AND asi_gs < 180;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 0 WHERE asi_gs > 100 AND asi_gs < 130;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 0 WHERE asi_gs > 202 AND asi_gs < 230;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 0 WHERE asi_gs < 39;
UPDATE zaf.ag_stress_idx_16013 SET asi_num = 0 WHERE asi_gs > 250;

UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.05, vci = '< 0.15' WHERE vci_gs > 30 AND vci_gs < 50;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.15, vci = '0.15 - 0.25' WHERE vci_gs > 50 AND vci_gs < 85;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.25, vci = '0.25 - 0.35' WHERE vci_gs > 140 AND vci_gs < 152;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.35, vci = '0.35 - 0.45' WHERE vci_gs > 206 AND vci_gs < 230;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.45, vci = '0.45 - 0.55' WHERE vci_gs > 230 AND vci_gs < 250;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.55, vci = '0.55 - 0.65' WHERE vci_gs > 200 AND vci_gs < 206;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.65, vci = '0.65 - 0.75' WHERE vci_gs > 151 AND vci_gs < 200;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.75, vci = '0.75 - 0.85' WHERE vci_gs > 95 AND vci_gs < 140;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 0.85, vci = '>= 0.85' WHERE vci_gs > 85 AND vci_gs < 95;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 10 WHERE vci_gs < 30;
UPDATE zaf.veg_cond_idx_1512 SET vci_num = 10 WHERE vci_gs > 250;

UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.05, vci = '< 0.15' WHERE vci_gs > 30 AND vci_gs < 50;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.15, vci = '0.15 - 0.25' WHERE vci_gs > 50 AND vci_gs < 85;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.25, vci = '0.25 - 0.35' WHERE vci_gs > 140 AND vci_gs < 152;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.35, vci = '0.35 - 0.45' WHERE vci_gs > 206 AND vci_gs < 230;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.45, vci = '0.45 - 0.55' WHERE vci_gs > 230 AND vci_gs < 250;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.55, vci = '0.55 - 0.65' WHERE vci_gs > 200 AND vci_gs < 206;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.65, vci = '0.65 - 0.75' WHERE vci_gs > 151 AND vci_gs < 200;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.75, vci = '0.75 - 0.85' WHERE vci_gs > 95 AND vci_gs < 140;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 0.85, vci = '>= 0.85' WHERE vci_gs > 85 AND vci_gs < 95;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 10 WHERE vci_gs < 30;
UPDATE zaf.veg_cond_idx_1601 SET vci_num = 10 WHERE vci_gs > 250;

COMMIT;

SELECT
    'Number of features for ASI ' || asi || ' are ' || COUNT(gid) AS "Count of asi"
  FROM
    zaf.ag_stress_idx_16013
  GROUP BY
    asi,
    asi_num
  ORDER BY
    asi_num DESC
  ;

SELECT
    'Number of features for VCI in Dec 2015' || vci || ' are ' || COUNT(gid) AS "Count of vci"
  FROM
    zaf.veg_cond_idx_1512
  GROUP BY
    vci,
    vci_num
  ORDER BY
    vci_num ASC
  ;

SELECT
    'Number of features for VCI in Jan 2016' || vci || ' are ' || COUNT(gid) AS "Count of vci"
  FROM
    zaf.veg_cond_idx_1601
  GROUP BY
    vci,
    vci_num
  ORDER BY
    vci_num ASC
  ;
