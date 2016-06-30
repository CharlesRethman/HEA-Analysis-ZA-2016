/*
 * Query to determine problem specs for affected vs unaffected regions by
 * breaking down averages.
 */

DROP TABLE IF EXISTS zaf.prob_crops;
DROP TABLE IF EXISTS zaf.prob_hazard;
DROP TABLE IF EXISTS zaf.t2;
DROP TABLE IF EXISTS zaf.t3;

DROP INDEX IF EXISTS zaf.vci_16_01_buffer_gidx;
DROP INDEX IF EXISTS zaf.landuse_agricregions_gidx;
DROP INDEX IF EXISTS zaf.prob_hazard_gidx;

CREATE INDEX vci_16_01_buffer_gidx ON zaf.vci_16_01_buffer USING GIST(the_geom);
CREATE INDEX landuse_agricregions_gidx ON zaf.landuse_agricregions USING GIST(the_geom);

CREATE TABLE zaf.prob_hazard (
    id SERIAL PRIMARY KEY,
    the_geom GEOMETRY(MULTIPOLYGON, 201100),
    ofa_year INTEGER,
    ofa_month INTEGER
  )
;


INSERT INTO zaf.prob_hazard (
   the_geom,
   ofa_year,
   ofa_month
   )
      SELECT
         ST_Multi(ST_Union(the_geom)) AS the_geom,
         r.ofa_year,
         r.ofa_month
      FROM
         zaf.vci_16_01_buffer,
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
            ) AS g
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


CREATE INDEX prob_hazard_gidx ON zaf.prob_hazard USING GIST(the_geom);

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

CREATE INDEX t2_gidx ON zaf.t2 USING GIST(the_geom);

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

BEGIN;



CREATE TABLE zaf.prob_crops (
    id SERIAL PRIMARY KEY,
    the_geom GEOMETRY(MULTIPOLYGON, 201100),
    "year" INTEGER,
    "month" INTEGER,
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
    "year",
    "month",
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
        "year",
        "month",
        ag_type,
        f.prov_code,
        cec,
        hazard,
        0.35,
        prov_area,
        ST_Area(f.the_geom)
      FROM
        (
          SELECT
              ST_Multi(ST_Union(ST_Intersection(zaf.t2.the_geom, zaf.prob_hazard.the_geom))) AS the_geom,
              "year",
              "month",
              ag_type,
              prov_code,
              'drought' AS hazard,
              sum(ST_Area(zaf.t2.the_geom)) AS prov_area
            FROM
              zaf.prob_hazard,
              zaf.t2
            WHERE
                ST_Intersects(zaf.t2.the_geom, zaf.prob_hazard.the_geom)
              AND
                NOT ST_IsEmpty(ST_Buffer(ST_Intersection(zaf.t2.the_geom, zaf.prob_hazard.the_geom),0.0))
            GROUP BY
              "year",
              "month",
              ag_type,
              prov_code,
              hazard
        ) AS f,
        zaf.t3
      WHERE
        f.prov_code = zaf.t3.prov_code
;



INSERT INTO zaf.prob_crops (
    the_geom,
    "year",
    "month",
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
        "year",
        "month",
        ag_type,
        f.prov_code,
        cec,
        hazard,
        (cec * prov_area - 0.35 * (prov_area - ST_Area(f.the_geom)))/ST_Area(f.the_geom),
        prov_area,
        ST_Area(f.the_geom)
      FROM
        (
          SELECT
              ST_Multi(ST_Union(ST_Difference(zaf.t2.the_geom, zaf.prob_hazard.the_geom))) AS the_geom,
              "year",
              "month",
              ag_type,
              prov_code,
              'less dry' AS hazard,
              sum(ST_Area(zaf.t2.the_geom)) AS prov_area
            FROM
              zaf.t2,
              zaf.prob_hazard
            WHERE
                ST_Intersects(zaf.t2.the_geom, zaf.prob_hazard.the_geom)
              AND
                NOT ST_IsEmpty(ST_Buffer(ST_Intersection(zaf.t2.the_geom, zaf.prob_hazard.the_geom),0.0))
            GROUP BY
              "year",
              "month",
              ag_type,
              prov_code,
              hazard
        ) AS f,
        zaf.t3
      WHERE
        f.prov_code = zaf.t3.prov_code
;
/*
INSERT INTO zaf.prob_crops (
    the_geom,
    "year",
    "month",
    ag_type,
    prov_code,
    cec_probspec,
    hazard,
    local_probspec
  )
    SELECT
        the_geom,
        "year",
        "month",
        ag_type,
        f.prov_code,
        cec,
        hazard,
        (cec * prov_area - 0.35 * (prov_area - ST_Area(f.the_geom)))/ST_Area(f.the_geom)
      FROM
        (
          SELECT
              the_geom,
              EXTRACT (YEAR FROM current_date) AS "year",
              EXTRACT (MONTH FROM current_date) AS "month",
              ag_type,
              prov_code,
              'less dry' AS hazard,
              ST_Area(the_geom) AS prov_area
            FROM
              zaf.t2
            WHERE
            gid NOT IN (
              SELECT
                  zaf.t2.gid
                FROM
                  zaf.t2,
                  zaf.prob_hazard
                WHERE
                  ST_Intersects(zaf.t2.the_geom, zaf.prob_hazard.the_geom)
                AND
                  NOT ST_IsEmpty(ST_Buffer(ST_Intersection(zaf.t2.the_geom, zaf.prob_hazard.the_geom),0.0))
            )
        ) AS f,
        zaf.t3
      WHERE
        f.prov_code = zaf.t3.prov_code
;*/



INSERT INTO zaf.prob_crops (
  the_geom,
  "year",
  "month",
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
      "year",
      "month",
      ag_type,
      prov_code,
      cec,
      hazard,
      0.3,
      type_area,
      ST_Area(g.the_geom)
    FROM
      (
        SELECT
            ST_Multi(ST_Union(ST_Intersection(f.the_geom, zaf.prob_hazard.the_geom))) AS the_geom,
            "year",
            "month",
            ag_type,
            prov_code,
            0.62 AS cec,
            'drought' AS hazard,
            sum(ST_Area(f.the_geom)) AS type_area
          FROM
            zaf.prob_hazard,
            (
              SELECT
                  the_geom,
                  "type" AS ag_type,
                  0 AS prov_code
                FROM
                  zaf.landuse_agricregions
                WHERE
                  "type" = 'Subsistence'
            ) AS f
          WHERE
              ST_Intersects(f.the_geom, zaf.prob_hazard.the_geom)
            AND
              NOT ST_IsEmpty(ST_Buffer(ST_Intersection(f.the_geom, zaf.prob_hazard.the_geom),0.0))
          GROUP BY
            "year",
            "month",
            ag_type,
            prov_code,
            cec,
            hazard
      ) AS g
;


INSERT INTO zaf.prob_crops (
  the_geom,
  "year",
  "month",
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
      "year",
      "month",
      ag_type,
      prov_code,
      cec,
      hazard,
      (cec * type_area - 0.3 * (type_area - ST_Area(g.the_geom)))/ST_Area(g.the_geom),
      type_area,
      ST_Area(g.the_geom)
    FROM
      (
        SELECT
            ST_Multi(ST_Union(ST_Difference(f.the_geom, zaf.prob_hazard.the_geom))) AS the_geom,
            "year",
            "month",
            ag_type,
            prov_code,
            0.62 AS cec,
            'less dry' AS hazard,
            sum(ST_Area(f.the_geom)) AS type_area
          FROM
            zaf.prob_hazard,
            (
              SELECT
                  the_geom,
                  "type" AS ag_type,
                  0 AS prov_code
                FROM
                  zaf.landuse_agricregions
                WHERE
                  "type" = 'Subsistence'
            ) AS f
          WHERE
              ST_Intersects(f.the_geom, zaf.prob_hazard.the_geom)
            AND
              NOT ST_IsEmpty(ST_Buffer(ST_Intersection(f.the_geom, zaf.prob_hazard.the_geom),0.0))
          GROUP BY
            "year",
            "month",
            ag_type,
            prov_code,
            cec,
            hazard
      ) AS g
;


COMMIT;


DROP INDEX IF EXISTS zaf.t2_gidx;
DROP TABLE IF EXISTS zaf.t2;
DROP TABLE IF EXISTS zaf.t3;


SELECT
    "year",
    "month",
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
