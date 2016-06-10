-- Purpose: to construct a table of outcomes by Small Area, Wealth Group, Wealth
-- Group Hazard (receive/don't receive social grants) and Thresholds that can be
-- summarised with a pivot table or filtered and joined to the Small Area layer
-- (zaf.demog_sas) to be map the outcome.
-- The pivot table will calculate total numbers of affected people and their
-- deficits by admin area an livelihood zone.

-- Index transaction: to speed up the the main insert query
BEGIN;

DROP INDEX IF EXISTS zaf.prob_hazard_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_sa_code_idx;

DROP INDEX IF EXISTS zaf.tbl_pop_agegender_12y_sa_code_idx;



-- Create indices if they do not exist
CREATE INDEX prob_hazard_gidx ON zaf.prob_hazard USING GIST (the_geom);

CREATE INDEX demog_sas_gidx ON zaf.demog_sas USING GIST (the_geom);

CREATE INDEX demog_sas_sa_code_idx
ON zaf.demog_sas
USING btree (sa_code);

CREATE INDEX tbl_pop_agegender_12y_sa_code_idx
ON zaf.tbl_pop_agegender_12y
USING btree (sa_code);


-- Remove any old table of affected small areas
DROP TABLE IF EXISTS zaf.demog_sas_ofa;

-- If it doesn't exist already, create a new table with the key outcome information for all affected
-- enumeration areas, with admin, livelihood zone, wealth group definition
-- social security, hazard and outcome information
CREATE TABLE IF NOT EXISTS zaf.demog_sas_ofa (
	gid serial primary key,
	the_geom geometry(multipolygon, 201100),
-- year and month of analysis (unique to each analysis event)
	ofa_year integer,
	ofa_month integer,
	sa_code integer,
	mn_code varchar(6),
	dc_code varchar(6),
	pr_code integer,
	-- population
	pop_size integer,
--	pop_curr numeric,
--	hh_curr numeric,
	-- livelihood zones: code, abbrev, name and wealth group
	lz_code integer,
	lz_affected varchar(30)
	)
;

-- Remove all previous records for the current analysis
DELETE FROM
	zaf.demog_sas_ofa
WHERE
 		ofa_year = EXTRACT(year FROM current_date)
	AND
		ofa_month = EXTRACT(month FROM current_date)
;

-- Done.
COMMIT;



-- Main transaction. Create an output table and populate it with the analysis.
BEGIN;

SELECT 'Add in the SAS that are completely contained within the hazard area'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
--	pop_curr,
--	hh_curr,
	lz_code,
	lz_affected
	)
		-- The SAs entirely within the affected area
		SELECT
			h.the_geom AS the_geom,
			EXTRACT(year FROM current_date) AS ofa_year,
			EXTRACT(month FROM current_date) AS ofa_month,
			h.sa_code,
			mn_code,
			dc_code,
			pr_code,
			pop_size,
			lz_code,
			'drought' AS lz_affected
		FROM
			(
				SELECT
					the_geom,
					f.sa_code,
					mn_code,
					dc_code,
					pr_code,
					total AS pop_size,
					lz_code
				FROM
					zaf.demog_sas AS f,
					zaf.tbl_pop_agegender_12y AS g
				WHERE
						f.sa_code = g.sa_code
				) AS h,
			zaf.prob_hazard AS i
		WHERE
				ST_Intersects(h.the_geom, i.the_geom)
			AND
				ST_Within(h.the_geom, i.the_geom)
;

SELECT 'Add in the EAS that have more than one-third of their area intersecting with the hazard area'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
		--	pop_curr,
		--	hh_curr,
	lz_code,
	lz_affected
	)
		-- The areas crossing, with more than one-third of the intesecting area
		-- WITHIN
		SELECT
			m.the_geom AS the_geom,
			EXTRACT(year FROM current_date) AS ofa_year,
			EXTRACT(month FROM current_date) AS ofa_month,
			m.sa_code,
			mn_code,
			dc_code,
			pr_code,
			pop_size,
			lz_code,
			'drought' AS lz_affected
		FROM
			(
				SELECT
					ST_Multi(ST_Buffer(ST_Intersection(f.the_geom, g.the_geom),0.0)) AS the_geom,
					sa_code
				FROM
					zaf.demog_sas AS f,
					zaf.prob_hazard AS g
				WHERE
						ST_Intersects(f.the_geom, g.the_geom)
					AND
					f.gid NOT IN (
						SELECT
							h.gid
						FROM
							zaf.demog_sas AS h,
							zaf.prob_hazard AS i
						WHERE
							ST_Within(h.the_geom, i.the_geom)
						)
				) AS j,
			(
				SELECT
					the_geom,
					k.sa_code,
					mn_code,
					dc_code,
					pr_code,
					total AS pop_size,
					lz_code
				FROM
					zaf.demog_sas AS k,
					zaf.tbl_pop_agegender_12y AS l
				WHERE
					k.sa_code = l.sa_code
				) AS m
		WHERE
				m.sa_code = j.sa_code
			AND
				3 * ST_Area(j.the_geom) > ST_Area(m.the_geom)
;

--		UNION
SELECT 'Add in the EAS that less than one-third of their area intersecting with the hazard area'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
		--	pop_curr,
		--	hh_curr,
	lz_code,
	lz_affected
	)
		SELECT
			m.the_geom AS the_geom,
			EXTRACT(year FROM current_date) AS ofa_year,
			EXTRACT(month FROM current_date) AS ofa_month,
			m.sa_code,
			mn_code,
			dc_code,
			pr_code,
			pop_size,
			lz_code,
			'normal' AS lz_affected
		FROM
			(
				SELECT
					ST_Multi(ST_Buffer(ST_Intersection(f.the_geom, g.the_geom),0.0)) AS the_geom,
					sa_code
				FROM
					zaf.demog_sas AS f,
					zaf.prob_hazard AS g
				WHERE
						ST_Intersects(f.the_geom, g.the_geom)
					AND
						f.gid NOT IN (
							SELECT
								h.gid
							FROM
								zaf.demog_sas AS h,
								zaf.prob_hazard AS i
							WHERE
								ST_Within(h.the_geom, i.the_geom)
							)
				) AS j,
			(
				SELECT
					gid,
					the_geom,
					k.sa_code,
					mn_code,
					dc_code,
					pr_code,
					total AS pop_size,
					lz_code
				FROM
					zaf.demog_sas AS k,
					zaf.tbl_pop_agegender_12y AS l
				WHERE
					k.sa_code = l.sa_code
				) AS m
		WHERE
				m.sa_code = j.sa_code
			AND
				ST_Area(m.the_geom) >= 3 * ST_Area(j.the_geom)
;

SELECT 'Add in the EAS that do NOT intersect at all with the hazard area'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
				--	pop_curr,
				--	hh_curr,
	lz_code,
	lz_affected
	)
				-- The areas that do not intersect
		SELECT
			the_geom,
			EXTRACT(year FROM current_date) AS ofa_year,
			EXTRACT(month FROM current_date) AS ofa_month,
			sa_code,
			mn_code,
			dc_code,
			pr_code,
			pop_size,
			lz_code,
			'normal' AS lz_affected
		FROM
			(
				SELECT
					gid,
					the_geom,
					f.sa_code,
					mn_code,
					dc_code,
					pr_code,
					total AS pop_size,
					lz_code
				FROM
					zaf.demog_sas AS f,
					zaf.tbl_pop_agegender_12y AS g
				WHERE
					f.sa_code = g.sa_code
				) AS h
		WHERE
			h.gid NOT IN (
				SELECT
					i.gid
				FROM
					zaf.demog_sas AS i,
					zaf.prob_hazard AS j
				WHERE
						ST_Intersects(i.the_geom, j.the_geom)
				)
;


COMMIT;


/*
--Transaction to present the data in a file and on StdOut
BEGIN;

-- Output the table to a CSV file for spreadsheet input
COPY (
	SELECT
			sa_code,
			region_cod AS region_code,
			region_nam AS region,
			constituen AS const_code,
			constitue1 AS constituency,
			lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' AS lz,
			hazard,
			f.ordnum || ' '|| zaf.demog_sas_ofa.wg AS wg,
			soc_sec,
			pop_size,
			pop_curr,
			round(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER), 0) AS pop_surv,
			round(pop_curr * pc_pop * CAST( lhood_def > 0.005 AS INTEGER), 0) AS pop_lhood,
			round(pop_curr * pc_pop * surv_def * 2100 / 3360.0 / 1000, 4) AS maize_eq,
			round(hh_curr * pc_pop * lhood_def, 0) AS lhood_nad
		FROM
			zaf.demog_sas_ofa,
			(VALUES (1, 'very poor'), (2, 'poor'), (3, 'middle'), (4, 'rich'), (4, 'better off'), (4, 'better-off')) AS f (ordnum,wg)
		WHERE
			lower(zaf.demog_sas_ofa.wg) = f.wg
	ORDER BY
		sa_code,
		hazard,
		soc_sec,
		f.ordnum
	)
TO
	'/Users/Charles/Documents/hea_analysis/namibia/2016.05/pop/outcome.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;

COPY (
	SELECT
			row_name[1] AS region,
			row_name[2] AS constituency,
			"56101: Kunene cattle and small stock (NAKCS)",
			"56102: Omusati-Omaheke-Otjozondjupa cattle ranching (NACCR)",
			"56103: Erongo-Kunene small stock and natural resources (NACSN)",
			"56105: Southern communal small stock (NACSS)",
			"56182: Central freehold cattle ranching (NAFCR)",
			"56184: Southern freehold small stock (NAFSS)",
			"56201: Northern border upland cereals and livestock (NAUCL)"
			"56202: North-central upland cereals and non-farm income (NAUCI)",
			"56203: Caprivi lowland maize and cattle (NALMC)"
		FROM
			crosstab('
				SELECT
						ARRAY[ region_nam::text, constitue1::text] AS row_name,
						lz_code || '': '' || lz_name || '' ('' || lz_abbrev || '')'' AS lz,
						ROUND(SUM(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER)), 0) AS pop_surv
					FROM
						zaf.demog_sas_ofa
					GROUP BY
						region_nam,
						constitue1,
						lz
					ORDER BY
						1,
						2
				') AS ct(
					row_name text[],
					"56101: Kunene cattle and small stock (NAKCS)" NUMERIC,
					"56102: Omusati-Omaheke-Otjozondjupa cattle ranching (NACCR)" NUMERIC,
					"56103: Erongo-Kunene small stock and natural resources (NACSN)" NUMERIC,
					"56105: Southern communal small stock (NACSS)" NUMERIC,
					"56182: Central freehold cattle ranching (NAFCR)" NUMERIC,
					"56184: Southern freehold small stock (NAFSS)" NUMERIC,
					"56201: Northern border upland cereals and livestock (NAUCL)" NUMERIC,
					"56202: North-central upland cereals and non-farm income (NAUCI)" NUMERIC,
					"56203: Caprivi lowland maize and cattle (NALMC)" NUMERIC
				)
	)
TO
	'/Users/Charles/Documents/hea_analysis/namibia/2016.05/pop/outcome_xtab.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;
*/

SELECT
		count(sa_code),
--		mn_code,
--		dc_code,
--		pr_code,
--		lz_code, -- || ': '  || lz_name || ' (' || lz_abbrev || ')' AS lz,
		lz_affected
--		pop_size,
--		pop_curr,
	FROM
		zaf.demog_sas_ofa
	GROUP BY
		lz_affected
--	ORDER BY
--		sa_code,
--		hazard,
;
