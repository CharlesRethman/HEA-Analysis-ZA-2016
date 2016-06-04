-- Purpose: to construct a table of outcomes that can be mapped an from which
-- total numbers of affected people and their deficits can be calculated.

-- Index transaction: to speed up the the main insert query
BEGIN;

-- Remove old indexes
DROP INDEX IF EXISTS zaf.vci_1601_buffer_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_gidx;

-- Recreate them or create new ones
CREATE INDEX vci_1601_buffer_gidx ON zaf.vci_1601_buffer_gidx USING GIST(the_geom);

CREATE INDEX demog_sas_gidx ON zaf.demog_sas USING GIST(the_geom);

-- Done.
COMMIT;



-- Main transaction. Create an output table and populate it with the analysis.
BEGIN;

-- Remove any old table of affected small areas
DROP TABLE IF EXISTS zaf.tbl_ofa_sas;

-- create a new table with the key outcome information for all affected
-- enumeration areas, with admin, livelihood zone, wealth group definition
-- social security, hazard and outcome information
CREATE TABLE zaf.tbl_ofa_sas (
	tid serial primary key,
-- year and month of analysis (unique to each analysis event)
	ofa_year integer,
	ofa_month integer,
--	the_geom GEOMETRY(MULTIPOLYGON, 300000),
	sa_code integer,
	mn_code varchar(6),
	dc_code varchar(6),
	pr_code integer,
	-- population
	pop_size integer,
	pop_curr numeric,
--	hh_curr numeric,
	-- livelihood zones: code, abbrev, name and wealth group
	lz_code integer,
--	lz_abbrev VARCHAR(5),
--	lz_name VARCHAR(254),
	wg integer,
	-- Whether they have social security (soc_sec) and the hazards they're
	-- affected by
	wg_affected varchar(30),
	lz_affected varchar(30),
	-- outcomes, percent population affected (pc_pop), livelihood deficit
	-- (lhood_def) and survival deficit (surv_def)
	pc_pop numeric,
	threshold varchar(30),
	deficit numeric,
--	surv_def NUMERIC
	)
;

-- insert the data where the hazard has been worst
SELECT 'Add in the EAS that are completely contained within the hazard area'::text;

INSERT INTO zaf.tbl_ofa_sas (
	EXTRACT (year FROM current_date),
	EXTRACT (month FROM current_date),
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	pop_curr,
--	hh_curr,
	lz_code,
--	lz_abbrev,
--	lz_name,
	wg,
	wg_affected,
	lz_affected,
	pc_pop,
	threshold,
	deficit
	)
	-- data comes from nested query combining SAs, SPI data, rural and urban livelihoods tables
	SELECT
			h.sa_code,
			h.mn_code,
			h.dc_code,
			h.pr_code,
			h.pop_size,
			h.pop_curr,
--			g.hh_curr,
			lz_code,
			wg,
			wg_affected,
			lz_affected,
			pc_pop,
			threshold,
			deficit
		FROM
			zaf.tbl_ofa_outcomes,
			(
				SELECT
						the_geom
					FROM
						zaf.vci_1601_buffer
				) AS f,
			(
				SELECT
						the_geom,
						sa_code,
						mn_code,
						dc_code,
						pr_code,
						zaf.demog_sas.pop_size,
						zaf.demog_sas.pop_size * pop_rate AS pop_curr,
--						zaf.demog_sas.hh_size * pop_2016 / zaf.tbl_pop_proj.pop_size  AS hh_curr,
						zaf.demog_sas.lz_code AS lz_code,
						h.lz_name,
						h.lz_abbrev
					FROM
						zaf.demog_sas,
						zaf.tbl_pop_agegender_12y,
						(
							SELECT
									dc_code,
									pop / total AS pop_rate,
								FROM
									(
										SELECT
												dc_name,
												sum(pop)
											AS
												pop
											FROM
												zaf.tbl_pop_proj
											WHERE
												year_mid = EXTRACT(year FROM current_date)
											GROUP BY
												dc_name
										) AS g,
										(
											SELECT
													dc_name
													total
												FROM
													zaf.tbl_pop_agegender_12y,
													zaf.demog_sas
												WHERE
													zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
												GROUP BY
													dc_name
											) AS h
								WHERE
									g.dc_code = h.dc_code
							) AS i
					WHERE
							zaf.demog_sas.sa_code = zaf.tbl_pop_agegender_12y.sa_code
						AND
							zaf.demog_sas.dc_code = i.dc_code
				) AS j
		WHERE
				j.lz_code = zaf.tbl_ofa_outcomes.lz_code
			AND
				ST_Within(j.the_geom, f.the_geom)
				hazard = 'Affected'
;

-- insert the data where the hazard is lighter
SELECT 'Add in all the hazard data in the less-affected area'::text;

INSERT INTO zaf.tbl_ofa_sas (
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

COMMIT;



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
			f.ordnum || ' '|| zaf.tbl_ofa_sas.wg AS wg,
			soc_sec,
			pop_size,
			pop_curr,
			round(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER), 0) AS pop_surv,
			round(pop_curr * pc_pop * CAST( lhood_def > 0.005 AS INTEGER), 0) AS pop_lhood,
			round(pop_curr * pc_pop * surv_def * 2100 / 3360.0 / 1000, 4) AS maize_eq,
			round(hh_curr * pc_pop * lhood_def, 0) AS lhood_nad
		FROM
			zaf.tbl_ofa_sas,
			(VALUES (1, 'very poor'), (2, 'poor'), (3, 'middle'), (4, 'rich'), (4, 'better off'), (4, 'better-off')) AS f (ordnum,wg)
		WHERE
			lower(zaf.tbl_ofa_sas.wg) = f.wg
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
						zaf.tbl_ofa_sas
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
/*
SELECT
		sa_code,
		region_nam AS region,
		constitue1 AS constituency,
		lz_code || ': '  || lz_name || ' (' || lz_abbrev || ')' AS lz,
		hazard,
		zaf.tbl_ofa_sas.wg,
		soc_sec AS s,
--		pop_size,
		pop_curr,
		round(pop_curr * pc_pop * CAST( surv_def > 0.005 AS INTEGER), 0) AS pop_surv,
		round(pop_curr * pc_pop * CAST( lhood_def > 0.005 AS INTEGER), 0) AS pop_lhood,
		round(pop_curr * pc_pop * surv_def * 2100 / 3360.0 / 1000, 4) AS maize_eq,
		round(hh_curr * pc_pop * lhood_def, 0) AS lhood_nad
	FROM
		zaf.tbl_ofa_sas,
		(VALUES (1, 'very poor'), (2, 'poor'), (3, 'middle'), (4, 'rich'), (4, 'better off'), (4, 'better-off')) AS f (ordnum,wg)
	WHERE
		lower(zaf.tbl_ofa_sas.wg) = f.wg
	ORDER BY
		sa_code,
		hazard,
		s,
		f.ordnum
;*/

COMMIT;

/*
COPY (*/
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
						zaf.tbl_ofa_sas
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
/*	)
TO
	'/Users/Charles/Documents/hea_analysis/namibia/2016.05/pop/outcome_xtab.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)*/
;
