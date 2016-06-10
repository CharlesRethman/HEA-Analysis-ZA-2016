CREATE INDEX IF NOT EXISTS demog_sas_ofa_lz_code_dc_mn_code_idx
  ON zaf.demog_sas_ofa(dc_code, mn_code, lz_code, lz_affected);
CREATE INDEX IF NOT EXISTS tbl_lz_mapping_lz_code_idx ON zaf.tbl_lz_mapping(lz_code, lz_analysis_code);
CREATE INDEX IF NOT EXISTS tbl_demog_sas_ofa_dc_code_idx ON zaf.demog_sas_ofa(dc_code);
CREATE INDEX IF NOT EXISTS tbl_ofa_analysis_lz_wg_code_affected_ofa_year_month_idx
  ON zaf.tbl_ofa_analysis(lz_code, lz_affected, wg_code, ofa_year, ofa_month);
CREATE INDEX IF NOT EXISTS demog_sas_mn_code_name_idx ON zaf.demog_sas(mn_code, mn_name);
CREATE INDEX IF NOT EXISTS admin3_dists_dc_code_idx ON zaf.admin3_dists(dc_code);
CREATE INDEX IF NOT EXISTS tbl_livezones_list_lz_code_idx ON zaf.tbl_livezones_list(lz_code);
CREATE INDEX IF NOT EXISTS tbl_pop_proj_dc_mdb_code_idx_year_mid_idx
  ON zaf.tbl_pop_proj(dc_mdb_code, year_mid);
CREATE INDEX IF NOT EXISTS admin3_dists_dc_mdb_code_idx
  ON zaf.admin3_dists(dc_mdb_code);
CREATE INDEX IF NOT EXISTS tbl_wgs_wg_code_idx ON zaf.tbl_wgs(wg_code);

CREATE TABLE IF NOT EXISTS zaf.tbl_ofa_outcomes (
  "tid" serial primary key,
  ofa_year integer,
  ofa_month integer,
  sa_code integer,
  municipality varchar(100),
  district varchar(100),
  province varchar(100),
  lz_code integer,
  lz_abbrev varchar(5),
  lz_name varchar(254),
  lz_analysis_code integer,
  lz_affected varchar(30),
  pop_size integer,
  pop_curr numeric,
  hh_size integer,
  wg_code integer,
  wg_name varchar(64),
  pc_wg numeric,
  pc_wg_affected numeric,
  wg_affected varchar(30),
  threshold varchar(30),
  deficit numeric
  )
;


DELETE FROM
  zaf.tbl_ofa_outcomes
WHERE
    ofa_year = EXTRACT(year FROM current_date)
  AND
    ofa_month = EXTRACT(month FROM current_date)
;


INSERT INTO zaf.tbl_ofa_outcomes (
  ofa_year,
  ofa_month,
  sa_code,
  municipality,
  district,
  province,
  lz_code,
  lz_abbrev,
  lz_name,
  lz_analysis_code,
  lz_affected,
  pop_size,
  pop_curr,
  hh_size,
  wg_code,
  wg_name,
  pc_wg,
  pc_wg_affected,
  wg_affected,
  threshold,
  deficit
  )
    SELECT
      h.ofa_year,
      h.ofa_month,
      sa_code,
      mn_name AS municipality,
      j.dc_name AS district,
      j.pr_name AS province,
      g.lz_code,
      lz_abbrev,
      lz_name,
      lz_analysis_code,
      f.lz_affected,
      pop_size,
      pop_size * pop_c / pop_y AS pop_curr,
      hh_size,
      q.wg_code,
      wg_name,
      pc_wg,
      CASE wg_affected
        WHEN 'grants'
        THEN 0.8
        ELSE 0.2
      END AS pc_wg_affected,
      wg_affected,
      threshold,
      deficit
    FROM
      zaf.demog_sas_ofa AS f,
      zaf.tbl_lz_mapping AS g,
      zaf.tbl_ofa_analysis AS h,
      (SELECT DISTINCT mn_code, mn_name FROM zaf.demog_sas) AS i,
      zaf.admin3_dists AS j,
      zaf.tbl_livezones_list AS k,
      (
        SELECT dc_code, sum(pop) AS pop_c
        FROM zaf.tbl_pop_proj, zaf.admin3_dists
        WHERE
            year_mid = EXTRACT(year FROM current_date)
          AND
            zaf.admin3_dists.dc_mdb_code = zaf.tbl_pop_proj.dc_mdb_code
        GROUP BY dc_code
        ) AS m,
      (
        SELECT dc_code, sum(pop_size) AS pop_y
        FROM zaf.demog_sas_ofa
        GROUP BY dc_code
        ) AS p,
      zaf.tbl_wgs AS q,
      zaf.tbl_wg_names as r
    WHERE
        f.lz_code = g.lz_code
      AND
        g.lz_analysis_code = h.lz_code
      AND
        f.lz_affected = h.lz_affected
      AND
        CAST(f.mn_code AS integer) = i.mn_code
      AND
        CAST(f.dc_code AS integer) = j.dc_code
      AND
        f.lz_code = k.lz_code
      AND
        h.ofa_year = EXTRACT(year FROM current_date)
      AND
        h.ofa_month = EXTRACT(month FROM current_date)
      AND
        m.dc_code = CAST(f.dc_code AS integer)
      AND
        p.dc_code = f.dc_code
      AND
        h.lz_code = q.lz_code
      AND
        h.wg_code = q.wg_code
      AND
        q.wg_code = r."tid"
    ORDER BY
  sa_code,
  wg_code,
  wg_affected,
  threshold
;


--Transaction to present the data in a file and on StdOut
BEGIN;

-- Output the table of food deficits to a CSV file for spreadsheet input
COPY (
	SELECT
		sa_code,
		municipality,
		district,
		province,
    E'\'' || lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		f.ordnum ||'-' || wg_name AS wg,
		wg_affected as "grant",
		pop_size,
		pop_curr,
		round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0) AS pop_food_def,
		round(pop_curr * pc_wg * pc_wg_affected * deficit * 2100 / 3360.0 / 1000, 4) AS def_maize_eq
	FROM
		zaf.tbl_ofa_outcomes,
		(VALUES
				(1, 'very poor'),
				(1, 'casuals'),
				(1, 'quintile1'),
				(2, 'poor'),
				(2, 'temporary'),
				(2, 'quintile2'),
				(3, 'middle'),
				(3, 'full-time'),
				(3, 'quintile3'),
				(4, 'rich'),
				(4, 'better off'),
				(4, 'better-off'),
				(4, 'quintile4'),
				(5, 'quintile5')
				) AS f (ordnum,wg)
	WHERE
			threshold = 'Food energy deficit'
		AND
			lower(wg_name) = f.wg
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
	ORDER BY
		sa_code,
		wg,
		"grant",
    threshold
	)
TO
	'/Users/Charles/Documents/hea_analysis/south_africa/2016.04/report/outcome_foodenergy_defs.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;

-- Output the table of food poverty line deficits to a CSV file for spreadsheet input
COPY (
	SELECT
		sa_code,
		municipality,
		district,
		province,
    E'\'' || lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		f.ordnum ||'-' || wg_name AS wg,
		wg_affected as "grant",
		pop_size,
		pop_curr,
		round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0) AS pop_fpl_def,
		round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4) AS fpl_deficit
	FROM
		zaf.tbl_ofa_outcomes,
		(VALUES
				(1, 'very poor'),
				(1, 'casuals'),
				(1, 'quintile1'),
				(2, 'poor'),
				(2, 'temporary'),
				(2, 'quintile2'),
				(3, 'middle'),
				(3, 'full-time'),
				(3, 'quintile3'),
				(4, 'rich'),
				(4, 'better off'),
				(4, 'better-off'),
				(4, 'quintile4'),
				(5, 'quintile5')
				) AS f (ordnum,wg)
	WHERE
			threshold = 'FPL deficit'
		AND
			lower(wg_name) = f.wg
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
  ORDER BY
    sa_code,
    wg,
    "grant",
    threshold
	)
TO
	'/Users/Charles/Documents/hea_analysis/south_africa/2016.04/report/outcome_fpl_defs.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;

-- Output the table of lower bound poverty line deficits to a CSV file for spreadsheet input
COPY (
	SELECT
		sa_code,
		municipality,
		district,
		province,
		E'\'' || lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		f.ordnum ||'-' || wg_name AS wg,
		wg_affected as "grant",
		pop_size,
		pop_curr,
		round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0) AS pop_lbpl_def,
		round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4) AS lbpl_deficit
	FROM
		zaf.tbl_ofa_outcomes,
		(VALUES
				(1, 'very poor'),
				(1, 'casuals'),
				(1, 'quintile1'),
				(2, 'poor'),
				(2, 'temporary'),
				(2, 'quintile2'),
				(3, 'middle'),
				(3, 'full-time'),
				(3, 'quintile3'),
				(4, 'rich'),
				(4, 'better off'),
				(4, 'better-off'),
				(4, 'quintile4'),
				(5, 'quintile5')
				) AS f (ordnum,wg)
	WHERE
			threshold = 'LBPL deficit'
		AND
			lower(wg_name) = f.wg
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
	ORDER BY
		sa_code,
		wg,
		"grant",
    threshold
	)
TO
	'/Users/Charles/Documents/hea_analysis/south_africa/2016.04/report/outcome_lbpl_defs.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;

-- Output the table of upper bound poverty line deficits to a CSV file for spreadsheet input
COPY (
	SELECT
		sa_code,
		municipality,
		district,
		province,
    E'\'' || lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		f.ordnum ||'-' || wg_name AS wg_name,
		wg_affected as "grant",
		pop_size,
		pop_curr,
		round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0) AS pop_ubpl_def,
		round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4) AS ubpl_deficit
	FROM
		zaf.tbl_ofa_outcomes,
		(VALUES
				(1, 'very poor'),
				(1, 'casuals'),
				(1, 'quintile1'),
				(2, 'poor'),
				(2, 'temporary'),
				(2, 'quintile2'),
				(3, 'middle'),
				(3, 'full-time'),
				(3, 'quintile3'),
				(4, 'rich'),
				(4, 'better off'),
				(4, 'better-off'),
				(4, 'quintile4'),
				(5, 'quintile5')
				) AS f (ordnum,wg)
	WHERE
			threshold = 'UBPL deficit'
		AND
			lower(wg_name) = f.wg
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
	ORDER BY
		sa_code,
		wg,
		"grant",
    threshold
	)
TO
	'/Users/Charles/Documents/hea_analysis/south_africa/2016.04/report/outcome_ubpl_defs.csv'
WITH (
	FORMAT CSV, DELIMITER ',', HEADER TRUE
	)
;


COMMIT;


CREATE VIEW zaf.vw_demog_sas_fooddef AS
  SELECT
    gid,
    the_geom,
		f.sa_code,
		mn_name AS municipality,
		dc_name AS district,
		pr_name AS province,
    E'\'' || f.lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		min(pop_size) AS pop_size,
		min(pop_curr) AS pop_curr,
    sum(round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0)) AS pop_food_def,
		sum(round(pop_curr * pc_wg * pc_wg_affected * deficit * 2100 / 3360.0 / 1000, 4)) AS def_maize_eq
	FROM
    zaf.demog_sas AS f,
		zaf.tbl_ofa_outcomes AS g
	WHERE
		  threshold = 'Food energy deficit'
    AND
      f.sa_code = g.sa_code
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
  GROUP BY
    gid,
    the_geom,
    f.sa_code,
    municipality,
    district,
    province,
    lz,
    hazard
/*	ORDER BY
		sa_code,
		wg,
		"grant"*/
;


CREATE VIEW zaf.vw_demog_sas_fpl AS
  SELECT
    gid,
    the_geom,
		f.sa_code,
		mn_name AS municipality,
		dc_name AS district,
		pr_name AS province,
    E'\'' || f.lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		min(pop_size) AS pop_size,
		min(pop_curr) AS pop_curr,
		sum(round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0)) AS pop_fpl_def,
		sum(round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4)) AS fpl_deficit
	FROM
    zaf.demog_sas AS f,
		zaf.tbl_ofa_outcomes AS g
	WHERE
		  threshold = 'FPL deficit'
    AND
      f.sa_code = g.sa_code
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
  GROUP BY
    gid,
    the_geom,
    f.sa_code,
    municipality,
    district,
    province,
    lz,
    hazard
/*	ORDER BY
		sa_code,
		wg,
		"grant"*/
;

CREATE VIEW zaf.vw_demog_sas_lbpl AS
  SELECT
    gid,
    the_geom,
		f.sa_code,
		mn_name AS municipality,
		dc_name AS district,
		pr_name AS province,
    E'\'' || f.lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		min(pop_size) AS pop_size,
		min(pop_curr) AS pop_curr,
		sum(round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0)) AS pop_lbpl_def,
		sum(round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4)) AS lbpl_deficit
	FROM
    zaf.demog_sas AS f,
		zaf.tbl_ofa_outcomes AS g
	WHERE
		  threshold = 'LBPL deficit'
    AND
      f.sa_code = g.sa_code
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
  GROUP BY
    gid,
    the_geom,
    f.sa_code,
    municipality,
    district,
    province,
    lz,
    hazard
/*	ORDER BY
		sa_code,
		wg,
		"grant"*/
;

CREATE VIEW zaf.vw_demog_sas_ubpl AS
  SELECT
    gid,
    the_geom,
		f.sa_code,
		mn_name AS municipality,
		dc_name AS district,
		pr_name AS province,
    E'\'' || f.lz_code || ': ' || lz_name || ' (' || lz_abbrev || ')' || E'\'' AS lz,
		lz_affected as hazard,
		min(pop_size) AS pop_size,
		min(pop_curr) AS pop_curr,
		sum(round(pop_curr * pc_wg * pc_wg_affected * CAST( deficit > 0.005 AS INTEGER), 0)) AS pop_ubpl_def,
		sum(round(pop_curr * pc_wg * pc_wg_affected * deficit / hh_size, 4)) AS ubpl_deficit
	FROM
    zaf.demog_sas AS f,
		zaf.tbl_ofa_outcomes AS g
	WHERE
		  threshold = 'UBPL deficit'
    AND
      f.sa_code = g.sa_code
    AND
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
  GROUP BY
    gid,
    the_geom,
    f.sa_code,
    municipality,
    district,
    province,
    lz,
    hazard
/*	ORDER BY
		sa_code,
		wg,
		"grant"*/
;


SELECT
	lz_affected,
	count(sa_code) AS num_records
	FROM
		zaf.tbl_ofa_outcomes
  WHERE
      ofa_year = EXTRACT(year FROM current_date)
    AND
      ofa_month= EXTRACT(month FROM current_date)
	GROUP BY
		lz_affected

UNION
SELECT
	'TOTAL' AS lz_affected,
	count(sa_code) AS num_records
FROM
	zaf.tbl_ofa_outcomes
WHERE
    ofa_year = EXTRACT(year FROM current_date)
  AND
    ofa_month= EXTRACT(month FROM current_date)

UNION
SELECT
	'Untouched TOTAL number of SAs & WGs' AS lz_affected,
	count(sa_code) * 2 * 4 AS num_records
FROM
	zaf.demog_sas AS f,
	zaf.tbl_wgs AS g,
  zaf.tbl_lz_mapping AS h
WHERE
	f.lz_code = h.lz_code AND h.lz_analysis_code = g.lz_code

ORDER BY lz_affected
;


SELECT
  gid,
  sa_code,
  municipality,
  district,
  province,
  left(lz,50) AS lz,
  hazard,
  pop_size,
  pop_curr,
  pop_fpl_def,
  fpl_deficit
FROM
  zaf.vw_demog_sas_fpl
/*WHERE
    ofa_year = EXTRACT(year FROM current_date)
  AND
    ofa_month= EXTRACT(month FROM current_date)*/
ORDER BY
  sa_code
;
