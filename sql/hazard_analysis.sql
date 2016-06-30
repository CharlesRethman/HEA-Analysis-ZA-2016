/*
 * Purpose: to construct a table of outcomes by Small Area, Wealth Group, Wealth Group Affected
 * Category (receive/don't receive social grants) and Thresholds that can be summarised with a pivot
 * table or filtered and joined to the Small Area layer (zaf.demog_sas) to be map the outcome.
 *
 * The pivot table will calculate total numbers of affected people and their deficits by admin area
 * an livelihood zone.
 *
 */

-- Indices, table creation and preparation transaction
BEGIN;

--Drop indices to so they can be recreated
DROP INDEX IF EXISTS zaf.prob_hazard_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_gidx;

DROP INDEX IF EXISTS zaf.demog_sas_sa_code_idx;

DROP INDEX IF EXISTS zaf.tbl_pop_agegender_12y_sa_code_idx;



-- Create indices if they do not exist
CREATE INDEX prob_hazard_gidx ON zaf.prob_hazard USING GIST (the_geom);

CREATE INDEX demog_sas_gidx ON zaf.demog_sas USING GIST (the_geom);

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

-- Done.
COMMIT;



-- Main transaction. Create an output table and populate it with the analysis.
BEGIN;


-- Remove all previous records for the current analysis
DELETE FROM
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
;


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
	lz_code,
	lz_affected
	)
		-- The SAs entirely within the affected area
		SELECT
			h.the_geom AS the_geom,
			r.ofa_year,
			r.ofa_month,
			h.sa_code,
			h.mn_code,
			h.dc_code,
			h.pr_code,
			h.pop_size,
			h.lz_code,
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
			zaf.prob_hazard AS i,
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
	lz_code,
	lz_affected
	)
		-- The areas crossing, with more than one-third of the intesecting area
		-- WITHIN
		SELECT
			m.the_geom AS the_geom,
			r.ofa_year,
			r.ofa_month,
			m.sa_code,
			m.mn_code,
			m.dc_code,
			m.pr_code,
			m.pop_size,
			m.lz_code,
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
			) AS m,
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
				m.sa_code = j.sa_code
			AND
				3 * ST_Area(j.the_geom) > ST_Area(m.the_geom)
;


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
	lz_code,
	lz_affected
	)
		SELECT
			m.the_geom AS the_geom,
			r.ofa_year,
			r.ofa_month,
			m.sa_code,
			m.mn_code,
			m.dc_code,
			m.pr_code,
			m.pop_size,
			m.lz_code,
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
			) AS m,
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
	lz_code,
	lz_affected
	)
				-- The areas that do not intersect
		SELECT
			h.the_geom,
			r.ofa_year,
			r.ofa_month,
			h.sa_code,
			h.mn_code,
			h.dc_code,
			h.pr_code,
			h.pop_size,
			h.lz_code,
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
			) AS h,
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


-- Present a count of all change SAs (can be checked against original number)
SELECT
	1 AS num,
	ofa_month,
	ofa_year,
	count(sa_code) AS num_sas,
	lz_affected AS lz_affected
FROM
	zaf.demog_sas_ofa
WHERE
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
		lz_affected
UNION SELECT
	2 AS num,
	ofa_month,
	ofa_year,
	count(sa_code) AS num_sas,
	'TOTAL' AS lz_affected
WHERE
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
ORDER BY
	num
;
