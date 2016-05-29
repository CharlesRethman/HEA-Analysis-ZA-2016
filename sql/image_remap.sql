ALTER TABLE zaf.veg_cond_idx_1512 DROP COLUMN IF EXISTS vci_map;

ALTER TABLE zaf.ag_stress_idx_16013 DROP COLUMN IF EXISTS asi_map;

ALTER TABLE zaf.veg_cond_idx_1512 ADD COLUMN vci_map INTEGER;

ALTER TABLE zaf.ag_stress_idx_16013 ADD COLUMN asi_map INTEGER;

UPDATE zaf.ag_stress_idx_16013 SET asi_map = 10 WHERE asi > 39 AND asi < 80;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 9 WHERE asi > 80 AND asi < 100;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 8 WHERE asi > 130 AND asi < 150;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 7 WHERE asi > 180 AND asi < 195;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 6 WHERE asi > 230 AND asi < 250;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 5 WHERE asi > 195 AND asi < 202;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 4 WHERE asi > 150 AND asi < 180;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 1 WHERE asi > 100 AND asi < 130;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 1 WHERE asi > 200 AND asi < 230;
UPDATE zaf.ag_stress_idx_16013 SET asi_map = 1 WHERE asi < 39;

UPDATE zaf.veg_cond_idx_1512 SET vci_map = 10 WHERE vci > 30 AND vci < 50;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 9 WHERE vci > 50 AND vci < 85;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 8 WHERE vci > 140 AND vci < 152;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 7 WHERE vci > 206 AND vci < 230;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 6 WHERE vci > 230 AND vci < 250;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 5 WHERE vci > 200 AND vci < 206;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 4 WHERE vci > 151 AND vci < 200;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 3 WHERE vci > 95 AND vci < 140;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 2 WHERE vci > 85 AND vci < 95;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 1 WHERE vci < 30;
UPDATE zaf.veg_cond_idx_1512 SET vci_map = 1 WHERE vci > 250;

SELECT 'Number of values for asi_map = ' || asi_map || ' are: ' || COUNT(gid) AS "Count of asi" FROM zaf.ag_stress_idx_16013 GROUP BY asi_map;

SELECT 'Number of values for vci_map = ' || vci_map || ' are: ' || COUNT(gid) AS "Count of vci" FROM zaf.veg_cond_idx_1512 GROUP BY vci_map;
