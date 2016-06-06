-- Purpose: to construct a table of outcomes by Small Area, Wealth Group, Wealth
-- Group Hazard (receive/don't receive social grants) and Thresholds that can be
-- summarised with a pivot table or filtered and joined to the Small Area layer
-- (zaf.demog_sas) to be map the outcome.
-- The pivot table will calculate total numbers of affected people and their
-- deficits by admin area an livelihood zone.

-- Index transaction: to speed up the the main insert query
BEGIN;

-- Remove old indexes
DROP INDEX IF EXISTS zaf.prob_hazard_gidx;
DROP INDEX IF EXISTS zaf.demog_sas_gidx;
DROP INDEX IF EXISTS prob_hazard_year_idx;
DROP INDEX IF EXISTS prob_hazard_month_idx;
DROP INDEX IF EXISTS tbl_pop_agegender_12y_sa_code_idx;
DROP INDEX IF EXISTS demog_sas_sa_code_idx;

-- Recreate them or create new ones
CREATE INDEX prob_hazard_gidx ON zaf.prob_hazard USING GIST(the_geom);
CREATE INDEX demog_sas_gidx ON zaf.demog_sas USING GIST(the_geom);
CREATE INDEX tbl_pop_proj_dc_mdb_code_idx ON zaf.tbl_pop_proj(dc_mdb_code);
CREATE INDEX prob_hazard_year_idx ON zaf.prob_hazard(year);
CREATE INDEX prob_hazard_month_idx ON zaf.prob_hazard(month);
CREATE INDEX tbl_pop_agegender_12y_sa_code_idx ON zaf.tbl_pop_agegender_12y(sa_code);
CREATE INDEX demog_sas_sa_code_idx ON zaf.demog_sas(sa_code);

--ALTER TABLE zaf.demog_sas_ofa_1 ADD COLUMN pop_curr numeric;


-- Remove any old table of affected small areas
DROP TABLE IF EXISTS zaf.demog_sas_ofa_1;

-- create a new table with the key outcome information for all affected
-- enumeration areas, with admin, livelihood zone, wealth group definition
-- social security, hazard and outcome information
CREATE TABLE zaf.demog_sas_ofa_1 (
	gid serial primary key,
	the_geom geometry(multipolygon, 201100),
	-- year and month of analysis (unique to each analysis event)
	ofa_year integer,
	ofa_month integer,
	sa_code integer,
	mn_name varchar(100),
	dc_code varchar(6),
	dc_name varchar(100),
	pr_name varchar(64),
	-- population
	pop_size integer,
	pop_curr numeric,
	-- livelihood zones: code, abbrev, name and wealth group
	lz_code integer,
	lz_abbrev VARCHAR(5),
	lz_name VARCHAR(254),
	wg_name varchar(64),
	pc_wg numeric,
	hh_size integer,
	--hazard area
	lz_affected varchar(30)
	-- Have social security?
	wg_affected varchar(30),
	pc_wg_affected numeric,
	-- outcomes, percent population affected (pc_pop), livelihood deficit
	-- (lhood_def) and survival deficit (surv_def)
	threshold varchar(30),
	deficit numeric,
	)
;

-- Done.
COMMIT;



-- Main transaction. Create an output table and populate it with the analysis.
--BEGIN;


-- insert the data where the hazard has been worst
SELECT 'Add in the SAs that are completely contained within the hazard area'::text;

EXPLAIN INSERT INTO zaf.demog_sas_ofa_1 (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_name,
	dc_code,
	dc_name,
	pr_name,
	pop_size,
	pop_curr,
	lz_code,
	lz_abbrev,
	lz_name,
	wg_name,
	pc_wg,
	hh_size,
	lz_affected,
	wg_affected,
	pc_wg_affected,
	threshold,
	deficit
	)
		SELECT
			j.the_geom AS the_geom,
			ofa_year,
			ofa_month,
			j.sa_code,
			mn_name,
			dc_code,
			dc_name,
			pr_name,
			pop_size,
			pop_curr,
			n.lz_code,
			lz_abbrev,
			lz_name,
			wg_name,
			pc_wg,
			hh_size,
			m.lz_affected,
			wg_affected,
			pc_wg_affected,
			threshold,
			deficit
		FROM
			(
				SELECT
					ofa_year,
					ofa_month,
					q.lz_code,
					lz_abbrev,
					lz_name,
					wg_name,
					pc_wg,
					hh_size,
					lz_affected,
					wg_affected,
					CASE wg_affected WHEN 'grants' THEN 0.8 ELSE 0.2 AS pc_wg_affected,
					threshold,
					deficit
				FROM
					zaf.tbl_ofa_outcomes AS p,
					zaf.tbl_livezones_list AS q,
					(
						SELECT wg_name
						FROM zaf.tbl_wgs, zaf.tbl_wg_names
						WHERE zaf.tbl_wgs.wg_code = zaf.tbl_wg_names.tid
						) AS r
				WHERE
						p.lz_code = q.lz_code
					AND
						p.wg_code = r.wg_code
					AND
						p.lz_code = r.lz_code
					AND
						ofa_year = EXTRACT(year FROM current_date)
					AND
						ofa_month = EXTRACT(month FROM current_date)
				) AS n
		INNER JOIN
			(
				SELECT
					j.the_geom,
					sa_code,
					mn_name,
					dc_code,
					dc_name,
					pr_name,
					total AS pop_size,
					total * pop_c / pop_y AS pop_curr,
					lz_code,
					'drought' AS lz_affected
				FROM
					zaf.prob_hazard AS k,
					(
						SELECT
							the_geom,
							g.sa_code,
							g.mn_name,
							g.dc_code,
							g.dc_name,
							g.pr_name,
							total AS pop_size,
							total * pop_c / pop_y AS pop_curr,
							lz_code,
							'drought' AS lz_affected
						FROM
							zaf.demog_sas AS g,
							zaf.tbl_pop_agegender_12y AS h,
							(
								SELECT CAST(dc_mdb_code AS varchar(6)) AS dc_mdb_code, sum(pop) AS pop_c
								FROM zaf.tbl_pop_proj
								WHERE year_mid = EXTRACT(year FROM current_date)
								GROUP BY dc_mdb_code
								) AS f,
							(
								SELECT dc_code, sum(total) AS pop_y
								FROM zaf.tbl_pop_agegender_12y, zaf.demog_sas
								WHERE zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
								GROUP BY dc_code
								) AS i
						WHERE
								g.sa_code = h.sa_code
							AND
								f.dc_mdb_code = g.dc_mdb_code
							AND
								g.dc_code = i.dc_code
						) AS j
				WHERE
						ST_Intersects(j.the_geom, k.the_geom)
					AND
						ST_Within(j.the_geom, k.the_geom)
				) AS m
		ON
				n.lz_code = m.lz_code
			AND
				n.lz_affected = m.lz_affected
;

--		UNION
SELECT 'Add in the SAs that have more than one-third of their area intersecting with the hazard area'::text;

EXPLAIN INSERT INTO zaf.demog_sas_ofa_1 (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_name,
	dc_code,
	dc_name,
	pr_name,
	pop_size,
	pop_curr,
	lz_code,
	lz_abbrev,
	lz_name,
	wg_name,
	pc_wg,
	hh_size,
	lz_affected,
	wg_affected,
	pc_wg_affected,
	threshold,
	deficit
	)
		-- The areas crossing, with more than one-third of the intesecting area
		-- WITHIN
		SELECT
			v.the_geom AS the_geom,
			ofa_year,
			ofa_month,
			q.sa_code,
			mn_name,
			dc_code,
			dc_name,
			pr_name,
			pop_size,
			pop_curr,
			lz_code,
			lz_abbrev,
			lz_name,
			wg_name,
			pc_wg,
			hh_size,
			s.lz_affected,
			wg_affected,
			pc_wg_affected,
			threshold,
			deficit
		FROM
			(
				SELECT
					ofa_year,
					ofa_month,
					q.lz_code,
					lz_abbrev,
					lz_name,
					wg_name,
					pc_wg,
					hh_size,
					lz_affected,
					wg_affected,
					CASE wg_affected WHEN 'grants' THEN 0.8 ELSE 0.2 AS pc_wg_affected,
					threshold,
					deficit
				FROM
					zaf.tbl_ofa_outcomes AS r,
					zaf.tbl_livezones_list AS s,
					(
						SELECT wg_name
						FROM zaf.tbl_wgs, zaf.tbl_wg_names
						WHERE zaf.tbl_wgs.wg_code = zaf.tbl_wg_names.tid
						) AS t
				WHERE
						r.lz_code = s.lz_code
					AND
						r.wg_code = t.wg_code
					AND
						r.lz_code = t.lz_code
					AND
						ofa_year = EXTRACT(year FROM current_date)
					AND
						ofa_month = EXTRACT(month FROM current_date)
				) AS u
		INNER JOIN
			(
				SELECT
					q.the_geom,
					q.sa_code,
					mn_name,
					dc_code,
					dc_name,
					pr_name,
					total AS pop_size,
					total * pop_c / pop_y AS pop_curr,
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
								NOT ST_Within(f.the_geom, g.the_geom)
						) AS j,
					(
						SELECT
							the_geom,
							m.sa_code,
							m.mn_name,
							m.dc_code,
							m.dc_name,
							m.pr_name,
							total AS pop_size,
							total * pop_c / pop_y AS pop_curr,
							lz_code,
							'drought' AS lz_affected
						FROM
							zaf.demog_sas AS m,
							zaf.tbl_pop_agegender_12y AS n,
							(
								SELECT CAST(dc_mdb_code AS varchar(6)) AS dc_mdb_code, sum(pop) AS pop_c
								FROM zaf.tbl_pop_proj
								WHERE year_mid = EXTRACT(year FROM current_date)
								GROUP BY dc_mdb_code
								) AS k,
							(
								SELECT dc_code, sum(total) AS pop_y
								FROM zaf.tbl_pop_agegender_12y, zaf.demog_sas
								WHERE zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
								GROUP BY dc_code
								) AS p
						WHERE
								m.sa_code = n.sa_code
							AND
								k.dc_mdb_code = m.dc_mdb_code
							AND
								m.dc_code = p.dc_code
						) AS q
				WHERE
						q.sa_code = j.sa_code
					AND
						3 * ST_Area(j.the_geom) > ST_Area(q.the_geom)
				) AS v
		ON
				u.lz_code = v.lz_code
			AND
				u.lz_affected = v.lz_affected
;

--		UNION
SELECT 'Add in the SAs that have less than one-third of their area intersecting with the hazard area'::text;
-- The areas crossing, with less than two-thirds of the intesecting area WITHIN
EXPLAIN INSERT INTO zaf.demog_sas_ofa_1 (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_name,
	dc_code,
	dc_name,
	pr_name,
	pop_size,
	pop_curr,
	lz_code,
	lz_abbrev,
	lz_name,
	wg_name,
	pc_wg,
	hh_size,
	lz_affected,
	wg_affected,
	pc_wg_affected,
	threshold,
	deficit
	)
		SELECT
			q.the_geom AS the_geom,
			ofa_year,
			ofa_month,
			q.sa_code,
			mn_name,
			dc_code,
			dc_name,
			pr_name,
			pop_size,
			pop_curr,
			lz_code,
			lz_abbrev,
			lz_name,
			wg_name,
			pc_wg,
			hh_size,
			s.lz_affected,
			wg_affected,
			pc_wg_affected,
			threshold,
			deficit
		FROM
			(
				SELECT
					ofa_year,
					ofa_month,
					q.lz_code,
					lz_abbrev,
					lz_name,
					wg_name,
					pc_wg,
					hh_size,
					lz_affected,
					wg_affected,
					CASE wg_affected WHEN 'grants' THEN 0.8 ELSE 0.2 AS pc_wg_affected,
					threshold,
					deficit
				FROM
					zaf.tbl_ofa_outcomes AS r,
					zaf.tbl_livezones_list AS s,
					(
						SELECT wg_name
						FROM zaf.tbl_wgs, zaf.tbl_wg_names
						WHERE zaf.tbl_wgs.wg_code = zaf.tbl_wg_names.tid
						) AS t
				WHERE
						r.lz_code = s.lz_code
					AND
						r.wg_code = t.wg_code
					AND
						r.lz_code = t.lz_code
					AND
						ofa_year = EXTRACT(year FROM current_date)
					AND
						ofa_month = EXTRACT(month FROM current_date)
				) AS u
		INNER JOIN
			(
				SELECT
					q.the_geom,
					q.sa_code,
					mn_name,
					dc_code,
					dc_name,
					pr_name,
					total AS pop_size,
					total * pop_c / pop_y AS pop_curr,
					lz_code,
					'drought' AS lz_affected
				FROM
					(
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
									NOT ST_Within(f.the_geom, g.the_geom)
							) AS j,
						(
							SELECT
								the_geom,
								m.sa_code,
								m.mn_name,
								m.dc_code,
								m.dc_name,
								m.pr_name,
								total AS pop_size,
								total * pop_c / pop_y AS pop_curr,
								lz_code,
								'normal' AS lz_affected
							FROM
								zaf.demog_sas AS m,
								zaf.tbl_pop_agegender_12y AS n,
								(
									SELECT CAST(dc_mdb_code AS varchar(6)) AS dc_mdb_code, sum(pop) AS pop_c
									FROM zaf.tbl_pop_proj
									WHERE year_mid = EXTRACT(year FROM current_date)
									GROUP BY dc_mdb_code
									) AS k,
								(
									SELECT dc_code, sum(total) AS pop_y
									FROM zaf.tbl_pop_agegender_12y, zaf.demog_sas
									WHERE zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
									GROUP BY dc_code
									) AS p
							WHERE
									m.sa_code = n.sa_code
								AND
									k.dc_mdb_code = m.dc_mdb_code
								AND
									m.dc_code = p.dc_code
							) AS q
				WHERE
						q.sa_code = j.sa_code
					AND
						ST_Area(q.the_geom) >= 3 * ST_Area(j.the_geom)
				) AS v
		ON
				u.lz_code = v.lz_code
			AND
				u.lz_affected = v.lz_affected
;

--		UNION
SELECT 'Add in the SAs that do NOT intersect at all with the hazard area'::text;

EXPLAIN INSERT INTO zaf.demog_sas_ofa_1 (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_name,
	dc_code,
	dc_name,
	pr_name,
	pop_size,
	pop_curr,
	lz_code,
	lz_abbrev,
	lz_name,
	wg_name,
	pc_wg,
	hh_size,
	lz_affected,
	wg_affected,
	pc_wg_affected,
	threshold,
	deficit
	)
				-- The areas that do not intersect
		SELECT
			the_geom,
			ofa_year,
			ofa_month,
			sa_code,
			mn_name,
			dc_code,
			dc_name,
			pr_name,
			pop_size,
			pop_curr,
			lz_code,
			lz_abbrev,
			lz_name,
			wg_name,
			pc_wg,
			hh_size,
			s.lz_affected,
			wg_affected,
			pc_wg_affected,
			threshold,
			deficit
		FROM
		(
			SELECT
				ofa_year,
				ofa_month,
				q.lz_code,
				lz_abbrev,
				lz_name,
				wg_name,
				pc_wg,
				hh_size,
				lz_affected,
				wg_affected,
				CASE wg_affected WHEN 'grants' THEN 0.8 ELSE 0.2 AS pc_wg_affected,
				threshold,
				deficit
			FROM
				zaf.tbl_ofa_outcomes AS p,
				zaf.tbl_livezones_list AS q,
				(
					SELECT wg_name
					FROM zaf.tbl_wgs, zaf.tbl_wg_names
					WHERE zaf.tbl_wgs.wg_code = zaf.tbl_wg_names.tid
					) AS r
			WHERE
					p.lz_code = q.lz_code
				AND
					p.wg_code = r.wg_code
				AND
					p.lz_code = r.lz_code
				AND
					ofa_year = EXTRACT(year FROM current_date)
				AND
					ofa_month = EXTRACT(month FROM current_date)
			) AS n
	INNER JOIN
		(
			(
				SELECT
					gid,
					the_geom,
					g.sa_code,
					g.mn_name,
					g.dc_code,
					g.dc_name,
					g.pr_name,
					total AS pop_size,
					total * pop_c / pop_y AS pop_curr,
					lz_code,
					'normal' AS lz_affected
				FROM
					(
						SELECT CAST(dc_mdb_code AS varchar(6)) AS dc_mdb_code, sum(pop) AS pop_c
						FROM zaf.tbl_pop_proj
						WHERE year_mid = EXTRACT(year FROM current_date)
						GROUP BY dc_mdb_code
						) AS f,
					zaf.demog_sas AS g,
					zaf.tbl_pop_agegender_12y AS h,
					(
						SELECT dc_code, sum(total) AS pop_y
						FROM zaf.tbl_pop_agegender_12y, zaf.demog_sas
						WHERE zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
						GROUP BY dc_code
						) AS i
				WHERE
						g.sa_code = h.sa_code
					AND
						f.dc_mdb_code = g.dc_mdb_code
					AND
						g.dc_code = i.dc_code
				) AS j
		WHERE
			j.gid NOT IN (
				SELECT
					k.gid
				FROM
					zaf.demog_sas AS k,
					zaf.prob_hazard AS m
				WHERE
						ST_Intersects(k.the_geom, m.the_geom)
				)
		) AS s
		ON
				n.lz_code = s.lz_code
			AND
				n.lz_affected = s.lz_affected

;

--COMMIT;


/*

-- insert the data where the hazard is lighter
SELECT 'Add in all the hazard data in the less-affected area'::text;

INSERT INTO zaf.demog_sas_ofa_1 (
	the_geom,
	sa_code,
	region_cod,
	constituen,
	constitue1,
	region_nam,
	pop_size,
	pop_curr,
	hh_curr,
	lz_code,
	lz_name,
	lz_abbrev,
	hazard,
	wg,
	soc_sec,
	pc_pop,
	lhood_def,
	surv_def
	)
	-- data comes from nested query combining EAs, hazard area, livelihoods and
	-- analysis tables
	SELECT
			g.the_geom,
			g.sa_code,
			g.region_cod,
			constituen,
			constitue1,
			region_nam,
			g.pop_size,
			g.pop_curr,
			g.hh_curr,
			g.lz_code,
			g.lz_name,
			lz_abbrev,
			hazard,
			wg,
			soc_sec,
			pc_pop,
			lhood_def,
			surv_def
		FROM
			zaf.tbl_outcomes,
			(
				SELECT
						the_geom,
						sa_code,
						zaf.demog_sas.region_cod,
						constituen,
						constitue1,
						region_nam,
						zaf.demog_sas.pop_size,
						zaf.demog_sas.pop_size * pop_2016 / zaf.tbl_pop_proj.pop_size AS pop_curr,
						zaf.demog_sas.hh_size * pop_2016 / zaf.tbl_pop_proj.pop_size  AS hh_curr,
						zaf.demog_sas.lz_code AS lz_code,
						h.lz_name,
						h.lz_abbrev
					FROM
						zaf.tbl_pop_proj,
						zaf.demog_sas,
						(
							SELECT lz_code, lz_name, lz_abbrev FROM zaf.livezones
							) AS h
					WHERE
							zaf.demog_sas.lz_code = h.lz_code
						AND
							zaf.demog_sas.lz_code < 56800
						AND
							zaf.demog_sas.region_cod = zaf.tbl_pop_proj.region_cod
				) AS g
		WHERE
				sa_code NOT IN (
					SELECT
							sa_code
						FROM
							zaf.demog_sas,
							zaf.buffer_20160515
						WHERE
							ST_Intersects(zaf.demog_sas.the_geom, zaf.buffer_20160515.the_geom)
					)
			AND
				g.lz_code = zaf.tbl_outcomes.lz_code
			AND
				hazard = 'Not affected'
;
*/


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
			f.ordnum || ' '|| zaf.demog_sas_ofa_1.wg AS wg,
			soc_sec,
			pop_size,
			pop_curr,
			round(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER), 0) AS pop_surv,
			round(pop_curr * pc_pop * CAST( lhood_def > 0.005 AS INTEGER), 0) AS pop_lhood,
			round(pop_curr * pc_pop * surv_def * 2100 / 3360.0 / 1000, 4) AS maize_eq,
			round(hh_curr * pc_pop * lhood_def, 0) AS lhood_nad
		FROM
			zaf.demog_sas_ofa_1,
			(VALUES (1, 'very poor'), (2, 'poor'), (3, 'middle'), (4, 'rich'), (4, 'better off'), (4, 'better-off')) AS f (ordnum,wg)
		WHERE
			lower(zaf.demog_sas_ofa_1.wg) = f.wg
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
						zaf.demog_sas_ofa_1
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
	lz_affected,
	count(sa_code)
--		mn_code,
--		dc_code,
--		pr_code,
--		lz_code, -- || ': '  || lz_name || ' (' || lz_abbrev || ')' AS lz,
--		zaf.demog_sas_ofa_1.wg,
--		soc_sec AS s,
--		pop_size,
--		pop_curr,
--		round(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER), 0) AS pop_surv,
--		round(pop_curr * pc_pop * CAST( lhood_def > 0.005 AS INTEGER), 0) AS pop_lhood,
--		round(pop_curr * pc_pop * surv_def * 2100 / 3360.0 / 1000, 4) AS maize_eq,
--		round(hh_curr * pc_pop * lhood_def, 0) AS lhood_nad
	FROM
		zaf.demog_sas_ofa_1
--		(VALUES (1, 'very poor'), (2, 'poor'), (3, 'middle'), (4, 'rich'), (4, 'better off'), (4, 'better-off')) AS f (ordnum,wg)
	GROUP BY
		lz_affected
--		lower(zaf.demog_sas_ofa_1.wg) = f.wg
--	ORDER BY
--		sa_code,
--		hazard,
--		s,
--		f.ordnum
UNION
SELECT
	'TOTAL' AS lz_affected,
	count(sa_code)
FROM
	zaf.demog_sas_ofa_1

UNION
SELECT
	'Untouched TOTAL number of SAs' AS lz_affected,
	count(sa_code)
FROM
	zaf.demog_sas,
	zaf.tbl_wgs
WHERE
	zaf.demog_sas.lz_code = zaf.tbl_wgs.lz_code

ORDER BY lz_affected
;
/*
COMMIT;


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
						lz_code,
						ROUND(SUM(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER)), 0) AS pop_surv
					FROM
						zaf.demog_sas_ofa_1
					GROUP BY
						region_nam,
						constitue1,
						lz_code
					ORDER BY
						1,
						2,
						3
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
