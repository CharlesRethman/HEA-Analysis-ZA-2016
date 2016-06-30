/*
 * Purpose: to construct a table of outcomes by Small Area, Wealth Group, Wealth Group Affected
 * Category (receive/don't receive social grants) and Thresholds that can be summarised with a pivot
 * table or filtered and joined to the Small Area layer (zaf.demog_sas) to be map the outcome.
 *
 * The pivot table will calculate total numbers of affected people and their deficits by admin area
 * an livelihood zone.
 *
 */

LISTEN warning_notices;

NOTIFY warning_notices, E'\n\nThis query will only work if you have specified a switch on the command line for the\nanalysis variable using the syntax:\n\n-v analysis=M-YYYY\n\nwhere M is a one- or two-digit number representing the month of analysis (1 to 12) and YYYY\nis a four-digit number representing the year of analysis.\n\n\n';

-- Indices, table creation and preparation transaction
BEGIN;

--Drop indices to so they can be recreated
--DROP INDEX IF EXISTS zaf.prob_hazard_the_geom_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_the_geom_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_sa_code_idx;

DROP INDEX IF EXISTS zaf.tbl_pop_agegender_12y_sa_code_idx;

DROP INDEX IF EXISTS zaf.t1_the_geom_gidx;

DROP INDEX IF EXISTS zaf.t1_sa_code_idx;

DROP INDEX IF EXISTS zaf.t2_the_geom_gidx;

-- Create indices if they do not exist
CREATE INDEX demog_sas_the_geom_gidx ON zaf.demog_sas USING gist (the_geom);

CREATE INDEX demog_sas_sa_code_idx ON zaf.demog_sas USING btree (sa_code);

CREATE INDEX tbl_pop_agegender_12y_sa_code_idx ON zaf.tbl_pop_agegender_12y USING btree (sa_code);


-- [records deleted instead] Remove any old table of affected small areas
-- DROP TABLE IF EXISTS zaf.demog_sas_ofa;

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
	-- population (census data only, current year will be added in next step)
	pop_size integer,
	-- livelihood zones: code, abbrev, name and wealth group
	lz_code integer,
	lz_affected varchar(30)
)
;

REINDEX INDEX zaf.prob_hazard_the_geom_gidx;


-- Done.
COMMIT;



-- Main transaction. Create an output table and populate it with the analysis.
NOTIFY warning_notices, E'\n\nAdding in the SAs. This takes quite a while. If any part fails, the entire process will\nbe rolled back and none of the SAs will be included\n\n\n';

BEGIN;

-- Create a temporary table with indices that combines the SAs and populations, to speed up the
-- queries
CREATE TABLE zaf.t1 (
	gid serial primary key,
	the_geom geometry(multipolygon, 201100),
	sa_code integer,
	mn_code varchar(6),
	dc_code varchar(6),
	pr_code integer,
	pop_size integer,
	lz_code integer
)
;

INSERT INTO zaf.t1 (
	the_geom,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	lz_code
)
SELECT
	f.the_geom,
	f.sa_code,
	f.mn_code,
	f.dc_code,
	f.pr_code,
	g.total AS pop_size,
	f.lz_code
FROM
	zaf.demog_sas AS f,
	zaf.tbl_pop_agegender_12y AS g
WHERE
	f.sa_code = g.sa_code
;

CREATE INDEX t1_the_geom_gidx ON zaf.t1 USING GIST (the_geom);

CREATE INDEX t1_sa_code_idx ON zaf.t1 USING btree (sa_code);


CREATE TABLE zaf.t2 (
	gid serial primary key,
	the_geom geometry(multipolygon, 201100),
	sa_code integer,
	ofa_year integer,
	ofa_month integer
)
;

EXPLAIN ANALYZE INSERT INTO zaf.t2 (
	the_geom,
	sa_code,
	ofa_year,
	ofa_month
)
	SELECT
		ST_Multi(ST_Buffer(ST_Intersection(f.the_geom, g.the_geom),0.0)) AS the_geom,
		f.sa_code,
		g.ofa_year,
		g.ofa_month
	FROM
		zaf.demog_sas AS f,
		zaf.prob_hazard AS g,
		(
			SELECT
            CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y END AS ofa_year,
	         CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
	      FROM (
	      	SELECT
            	p.y,
	            CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
            FROM (
	            SELECT
	            	substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
	            	substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
	         ) AS p
	      ) AS q
	   ) AS r
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
		AND
			g.ofa_year = r.ofa_year
		AND
			g.ofa_month = r.ofa_month
;

CREATE INDEX t2_the_geom_gidx ON zaf.t2 USING gist (the_geom);



-- Remove all previous records for the current analysis specified in the :analysis variable (-v
-- analysis=M-YYYY in the command line where M is a number (1 to 12) representing the month of
-- analysis and YYYY is a four-digit number (1980 to current year) representing the year of
-- analysis)
DELETE FROM
	zaf.demog_sas_ofa
WHERE
 		ofa_year = (
			SELECT
				--Check that 01-month-year is not before 01-01-1980 or after the curent date. If so, force to the current month and year.
				CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y	END AS ofa_year
				FROM (
					SELECT
						p.y,
						--make sure the value of the month number is 1..12 only.
						CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
					FROM (
						SELECT
							-- gets the year, month values from the :analysis variable (TEXT) and coerces
							-- them to INTEGERs.
							substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
							substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
					) AS p
				) AS q
		)
	AND
		ofa_month = (
			SELECT
				CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
				FROM (
					SELECT
						p.y,
						CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
					FROM (
						SELECT
							substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
							substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
					) AS p
				) AS q
		)
;


SELECT 'Adding in the SAs that are completely contained within the hazard area ...'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	lz_code,
	lz_affected
)
	-- The SAs entirely within the affected area
	SELECT
		f.the_geom AS the_geom,
		r.ofa_year,
		r.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		'drought' AS lz_affected
	FROM
		zaf.t1 AS f,
		zaf.prob_hazard AS g,
		(
			SELECT
         	CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y END AS ofa_year,
         	CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
         FROM (
         	SELECT
            	p.y,
            	CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
            FROM (
            	SELECT
               	substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
               	substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
            ) AS p
         ) AS q
      ) AS r
	WHERE
			ST_Intersects(f.the_geom, g.the_geom)
		AND
			ST_Within(f.the_geom, g.the_geom)
		AND
			g.ofa_year = r.ofa_year
		AND
			g.ofa_month = r.ofa_month
;


SELECT 'Add in the SAs that have more than one-third of their area intersecting with the hazard area ...'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	lz_code,
	lz_affected
)
	-- The areas crossing, with more than one-third of the intesecting area
	-- WITHIN
	SELECT
		f.the_geom,
		g.ofa_year,
		g.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		'drought' AS lz_affected
	FROM
		zaf.t1 AS f,
		zaf.t2 AS g
	WHERE
		f.sa_code = g.sa_code
	GROUP BY
		f.the_geom,
		g.ofa_year,
		g.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		lz_affected
	HAVING 3 * sum(ST_Area(g.the_geom)) > ST_Area(f.the_geom)
;


SELECT 'Add in the SAs that less than one-third of their area intersecting with the hazard area ...'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	lz_code,
	lz_affected
)
	SELECT
		f.the_geom AS the_geom,
		g.ofa_year,
		g.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		'normal' AS lz_affected
	FROM
		zaf.t1 AS f,
		zaf.t2 AS g
	WHERE
		g.sa_code = f.sa_code
	GROUP BY
		f.the_geom,
		g.ofa_year,
		g.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		lz_affected
	HAVING sum(ST_Area(g.the_geom)) >= 3 * ST_Area(f.the_geom)
;


SELECT 'Add in the SAs that do NOT intersect at all with the hazard area ...'::text;

EXPLAIN ANALYZE INSERT INTO zaf.demog_sas_ofa (
	the_geom,
	ofa_year,
	ofa_month,
	sa_code,
	mn_code,
	dc_code,
	pr_code,
	pop_size,
	lz_code,
	lz_affected
)
	-- The areas that do not intersect
	SELECT
		f.the_geom,
		r.ofa_year,
		r.ofa_month,
		f.sa_code,
		f.mn_code,
		f.dc_code,
		f.pr_code,
		f.pop_size,
		f.lz_code,
		'normal' AS lz_affected
	FROM
		zaf.t1 AS f,
		(
			SELECT
         	CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y END AS ofa_year,
	         CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
         FROM (
	         SELECT
	         	p.y,
	         	CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
         	FROM (
               SELECT
	               substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
	            	substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
	         ) AS p
	      ) AS q
	   ) AS r
	WHERE
		f.gid NOT IN (
			SELECT
				h.gid
			FROM
				zaf.demog_sas AS h,
				zaf.prob_hazard AS i
			WHERE
					ST_Intersects(h.the_geom, i.the_geom)
				AND
					i.ofa_year = r.ofa_year
				AND
					i.ofa_month = r.ofa_month
		)
;

DROP INDEX IF EXISTS zaf.t1_the_geom_gidx;

DROP INDEX IF EXISTS zaf.t1_sa_code_idx;

DROP TABLE IF EXISTS zaf.t1;

DROP INDEX IF EXISTS zaf.t2_the_geon_gidx;

DROP TABLE IF EXISTS zaf.t2;


COMMIT;



NOTIFY warning_notices, E'\n\nDone.\nOutputting a count of affected rows in table \"zaf.demog_sas_ofa\"\n\n\n';


-- Present a count of all changed SAs (can be checked against original number of SAs) for the
-- current analysis
SELECT
	1 AS num,
	ofa_month,
	ofa_year,
	count(sa_code) AS num_sas,
	lz_affected AS lz_affected
FROM
	zaf.demog_sas_ofa
WHERE
 		ofa_year = (
			SELECT
				CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y	END AS ofa_year
			FROM (
				SELECT
					p.y,
					CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
				FROM (
					SELECT
						substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
						substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
				) AS p
			) AS q
		)
	AND
		ofa_month = (
			SELECT
				CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
			FROM (
				SELECT
					p.y,
					CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
				FROM (
					SELECT
						substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
						substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
				) AS p
			) AS q
		)
GROUP BY
	num,
	ofa_month,
	ofa_year,
	lz_affected
UNION SELECT
	2 AS num,
	ofa_month,
	ofa_year,
	count(sa_code) AS num_sas,
	'TOTAL' AS lz_affected
WHERE
		ofa_year = (
			SELECT
				CASE WHEN (date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date) THEN extract (year from current_date) ELSE q.y	END AS ofa_year
			FROM (
				SELECT
					p.y,
					CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
				FROM (
					SELECT
						substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
						substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
				) AS p
			) AS q
		)
	AND
		ofa_month = (
			SELECT
				CASE WHEN date (q.y::text || '-' || q.m::text || '-01') < date '1980-01-01' OR date (q.y::text || '-' || q.m::text || '-01') > current_date THEN extract (month from current_date) ELSE q.m END AS ofa_month
			FROM (
				SELECT
					p.y,
					CASE WHEN p.m > 12 THEN 12 WHEN p.m < 1 THEN 1 ELSE p.m END AS m
				FROM (
					SELECT
						substring( :'analysis' from  position( '-' in :'analysis' ) + 1 for length( :'analysis' ) - position( '-' in :'analysis' ))::integer AS y,
						substring( :'analysis' from 1 for position( '-' in :'analysis' ) - 1)::integer AS m
				) AS p
			) AS q
		)
GROUP BY
	num,
	ofa_month,
	ofa_year,
	lz_affected
ORDER BY
	num
;

UNLISTEN warning_notices;
