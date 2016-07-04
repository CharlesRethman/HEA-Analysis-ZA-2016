/*
 * Query to determine problem specs for affected vs unaffected regions by
 * breaking down averages.
 */


SELECT E'This query will only work if you have specified two switches on the command \nline for the \'analysis\' and \'hazard\' variables, using the syntax:\n\n-v analysis=M-YYYY -v hazard=HAZARD_TYPE\n\nwhere M is a one- or two-digit number representing the month of analysis (1 to \n12), YYYY is a four-digit number representing the year of analysis and \nHAZARD_TYPE is a one-word (no whitespace) description of the hazard.\n'::text AS "NOTICE";


DROP TABLE IF EXISTS zaf.prob_crops;
DROP TABLE IF EXISTS zaf.t2;
DROP TABLE IF EXISTS zaf.t3;
DROP TABLE IF EXISTS zaf.t4;

DROP INDEX IF EXISTS zaf.rs_vci_16_01_buffer_the_geom_gidx;
DROP INDEX IF EXISTS zaf.landuse_agricregions_the_geom_gidx;
DROP INDEX IF EXISTS zaf.t2_the_geom_gidx;
DROP INDEX IF EXISTS zaf.t3_prov_code_idx;
--DROP INDEX IF EXISTS zaf.prob_hazard_gidx;

CREATE INDEX rs_vci_16_01_buffer_the_geom_gidx ON zaf.rs_vci_16_01_buffer USING GIST(the_geom);
CREATE INDEX landuse_agricregions_the_geom_gidx ON zaf.landuse_agricregions USING GIST(the_geom);

CREATE TABLE IF NOT EXISTS zaf.prob_hazard (
    id serial primary key,
    the_geom geometry(multipolygon, 201100),
    ofa_year integer,
    ofa_month integer
  )
;

CREATE TABLE zaf.t4 (
	gid serial primary key,
	the_geom geometry(multipolygon, 201100),
   ofa_year integer,
   ofa_month integer
)
;

-- Remove all previous records for the current analysis
DELETE FROM
	zaf.prob_hazard
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


INSERT INTO zaf.t4 (
   the_geom,
   ofa_year,
   ofa_month
   )
      SELECT
         ST_Multi(ST_Union(the_geom)) AS the_geom,
         r.ofa_year,
         r.ofa_month
      FROM
         zaf.rs_vci_16_01_buffer,
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
            vci = '< 0.15'
         OR
            vci = '0.25 - 0.35'
         OR
            vci = '0.15 - 0.25'
      GROUP BY
         ofa_year,
         ofa_month
;

INSERT INTO zaf.prob_hazard (
	the_geom,
   ofa_year,
   ofa_month
)
   SELECT
      ST_Multi((ST_Dump(the_geom)).geom) AS the_geom,
      ofa_year,
      ofa_month
   FROM
      zaf.t4
;


REINDEX INDEX zaf.prob_hazard_the_geom_gidx;

CREATE TABLE zaf.t2 (
    gid SERIAL PRIMARY KEY,
    the_geom GEOMETRY(MULTIPOLYGON, 201100),
    ag_type VARCHAR(30),
    prov_code INTEGER
  )
;

INSERT INTO zaf.t2 (
    the_geom,
    ag_type,
    prov_code
  )
    SELECT
        ST_Multi(ST_Intersection(zaf.landuse_agricregions.the_geom, zaf.admin2_provs.the_geom)) AS the_geom,
        zaf.landuse_agricregions."type" AS ag_type,
        prov_code
      FROM
        zaf.landuse_agricregions,
        zaf.admin2_provs
      WHERE
          ST_Intersects(zaf.landuse_agricregions.the_geom, zaf.admin2_provs.the_geom)
        AND
          NOT ST_IsEmpty(ST_Buffer(ST_Intersection(
            zaf.landuse_agricregions.the_geom,
            zaf.admin2_provs.the_geom
          ), 0.0))
        AND
          prov_code NOTNULL
        AND (
            zaf.landuse_agricregions."type" = 'Grains'
--          OR
--            zaf.landuse_agricregions."type" = 'Subsistence'
        )
;

CREATE INDEX t2_the_geom_gidx ON zaf.t2 USING GIST(the_geom);

CREATE TABLE ZAF.t3 (
  prov_code INTEGER PRIMARY KEY,
  cec NUMERIC
);

INSERT INTO zaf.t3 (
  prov_code,
  cec
)
  VALUES
    (1, 1.67),
    (2, 0.54),
    (3, 1.41),
    (4, 0.42),
    (5, 0.75),
    (6, 0.59),
    (7, 0.56),
    (8, 0.66),
    (9, 1.13)
;

CREATE INDEX t3_prov_code_idx ON zaf.t3 USING btree (prov_code);

BEGIN;



CREATE TABLE zaf.prob_crops (
   id SERIAL PRIMARY KEY,
   the_geom GEOMETRY(MULTIPOLYGON, 201100),
   ofa_year INTEGER,
   ofa_month INTEGER,
   ag_type VARCHAR(30),
   prov_code INTEGER,
   cec_probspec NUMERIC,
   hazard VARCHAR(20),
   local_probspec NUMERIC,
   area_total NUMERIC,
   area_local NUMERIC
)
;


INSERT INTO zaf.prob_crops (
   the_geom,
   ofa_year,
   ofa_month,
   ag_type,
   prov_code,
   cec_probspec,
   hazard,
   local_probspec,
   area_total,
   area_local
)
   SELECT
      h.the_geom,
      h.ofa_year,
      h.ofa_month,
      h.ag_type,
      h.prov_code,
      i.cec,
      h.hazard,
      0.35 AS local_probspec,
      h.prov_area,
      ST_Area(h.the_geom) AS area_local
   FROM
      (
         SELECT
            ST_Multi(ST_Union(ST_Intersection(g.the_geom, f.the_geom))) AS the_geom,
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            :'hazard' AS hazard,
            sum(ST_Area(g.the_geom)) AS prov_area
         FROM
            zaf.t4 AS f,
            zaf.t2 AS g
         WHERE
               ST_Intersects(g.the_geom, f.the_geom)
            AND
               NOT ST_IsEmpty(ST_Buffer(ST_Intersection(g.the_geom, f.the_geom),0.0))
         GROUP BY
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            hazard
      ) AS h,
      zaf.t3 AS i
   WHERE
      h.prov_code = i.prov_code
;


INSERT INTO zaf.prob_crops (
   the_geom,
   ofa_year,
   ofa_month,
   ag_type,
   prov_code,
   cec_probspec,
   hazard,
   local_probspec,
   area_total,
   area_local
)
   SELECT
      h.the_geom,
      h.ofa_year,
      h.ofa_month,
      h.ag_type,
      h.prov_code,
      i.cec,
      h.hazard,
      (i.cec * h.prov_area - 0.35 * (h.prov_area - ST_Area(h.the_geom)))/ST_Area(h.the_geom),
      h.prov_area,
      ST_Area(h.the_geom)
   FROM
      (
         SELECT
            ST_Multi(ST_Union(ST_Difference(g.the_geom, f.the_geom))) AS the_geom,
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            'normal' AS hazard,
            sum(ST_Area(g.the_geom)) AS prov_area
         FROM
            zaf.t4 AS f,
            zaf.t2 AS g
         WHERE
               ST_Intersects(f.the_geom, g.the_geom)
            AND
               NOT ST_IsEmpty(ST_Buffer(ST_Intersection(f.the_geom, g.the_geom),0.0))
         GROUP BY
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            hazard
      ) AS h,
      zaf.t3 AS i
      WHERE
        h.prov_code = i.prov_code
;


INSERT INTO zaf.prob_crops (
   the_geom,
   ofa_year,
   ofa_month,
   ag_type,
   prov_code,
   cec_probspec,
   hazard,
   local_probspec,
   area_total,
   area_local
)
   SELECT
      the_geom,
      ofa_year,
      ofa_month,
      ag_type,
      prov_code,
      cec,
      hazard,
      0.3,
      type_area,
      ST_Area(h.the_geom)
   FROM
      (
         SELECT
            ST_Multi(ST_Union(ST_Intersection(g.the_geom, f.the_geom))) AS the_geom,
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            0.62 AS cec,
            :'hazard' AS hazard,
            sum(ST_Area(g.the_geom)) AS type_area
         FROM
            zaf.t4 AS f,
            (
               SELECT
                  the_geom,
                  "type" AS ag_type,
                  0 AS prov_code
               FROM
                  zaf.landuse_agricregions
               WHERE
                  "type" = 'Subsistence'
            ) AS g
         WHERE
               ST_Intersects(g.the_geom, f.the_geom)
            AND
               NOT ST_IsEmpty(ST_Buffer(ST_Intersection(g.the_geom, f.the_geom),0.0))
         GROUP BY
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            cec,
            hazard
      ) AS h
;


INSERT INTO zaf.prob_crops (
   the_geom,
   ofa_year,
   ofa_month,
   ag_type,
   prov_code,
   cec_probspec,
   hazard,
   local_probspec,
   area_total,
   area_local
)
   SELECT
      the_geom,
      ofa_year,
      ofa_month,
      ag_type,
      prov_code,
      cec,
      hazard,
      (cec * type_area - 0.3 * (type_area - ST_Area(h.the_geom)))/ST_Area(h.the_geom),
      type_area,
      ST_Area(h.the_geom)
   FROM
      (
         SELECT
            ST_Multi(ST_Union(ST_Difference(g.the_geom, f.the_geom))) AS the_geom,
            f.ofa_year,
            f.ofa_month,
            g.ag_type,
            g.prov_code,
            0.62 AS cec,
            'normal' AS hazard,
            sum(ST_Area(g.the_geom)) AS type_area
         FROM
            zaf.t4 AS f,
            (
              SELECT
                  the_geom,
                  "type" AS ag_type,
                  0 AS prov_code
                FROM
                  zaf.landuse_agricregions
                WHERE
                  "type" = 'Subsistence'
            ) AS g
          WHERE
              ST_Intersects(g.the_geom, f.the_geom)
            AND
              NOT ST_IsEmpty(ST_Buffer(ST_Intersection(g.the_geom, f.the_geom),0.0))
          GROUP BY
            ofa_year,
            ofa_month,
            ag_type,
            prov_code,
            cec,
            hazard
      ) AS h
;


COMMIT;



DROP INDEX IF EXISTS zaf.t2_the_geon_gidx;
DROP INDEX IF EXISTS zaf.t3_prov_code_idx;
DROP TABLE IF EXISTS zaf.t2;
DROP TABLE IF EXISTS zaf.t3;
DROP TABLE IF EXISTS zaf.t4;


SELECT
    ofa_year,
    ofa_month,
    province,
    ag_type,
    hazard,
    round(cec_probspec * 100, 0)::text || '%' AS cec,
    round(local_probspec * 100, 0)::text || '%' AS local,
    round(area_total / 10000.0,0) AS ha_total,
    round(area_local / 10000.0,0) AS ha_local,
    round(area_local * 100 / area_total, 0)::text || '%' AS pc_affected
  FROM
    zaf.prob_crops,
    (
      SELECT DISTINCT
          province,
          prov_code
        FROM
          zaf.admin2_provs
      UNION SELECT
          'All provinces' AS province,
          0 AS prov_code
    ) AS f
  WHERE
      zaf.prob_crops.prov_code = f.prov_code
  ORDER BY
    province,
    ag_type,
    hazard
;
