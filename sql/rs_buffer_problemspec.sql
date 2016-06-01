/*
 * Query to determine problem specs for affected vs unaffected regions by
 * breaking down averages.
 */

DROP TABLE IF EXISTS zaf.crops_probspecs;

DROP INDEX IF EXISTS zaf.vci_1601_buffer_gidx;
DROP INDEX IF EXISTS zaf.landuse_agricregions_gidx;

CREATE INDEX vci_1601_buffer_gidx ON zaf.vci_1601_buffer USING GIST(the_geom);
CREATE INDEX landuse_agricregions_gidx ON zaf.landuse_agricregions USING GIST(the_geom);

CREATE TABLE zaf.crops_probspecs (
    id SERIAL PRIMARY KEY,
    the_geom GEOMETRY(MULTIPOLYGON, 201100),
    "year" INTEGER,
    "month" INTEGER,
    crop VARCHAR(20),
    prov_code INTEGER,
    cec_probspec NUMERIC,
    hazard VARCHAR(20),
    local_probspec NUMERIC
  )
;

INSERT INTO zaf.crops_probspecs (
    the_geom,
    "year",
    "month",
    crop,
    prov_code,
    cec_probspec,
    hazard,
    local_probspec
  )
    SELECT
        h.the_geom,
        2016 AS "year",
        5 AS "month",
        'white maize' AS "crop",
        h.prov_code,
        i.cec,
        h.hazard,
        0
      FROM
        (
          SELECT
              ST_Multi(ST_Intersection(f.the_geom, g.the_geom)) AS the_geom,
              g.prov_code,
              f.hazard
            FROM
              (
                SELECT
                  ST_Multi((ST_Dump(ST_Union(the_geom))).geom) AS the_geom,
                  'drought' AS hazard
                FROM
                  zaf.vci_1601_buffer
                WHERE
                    vci = '< 0.15'
                  OR
                    vci = '0.25 - 0.35'
                  OR
                    vci = '0.15 - 0.25'
              ) AS f,
              (
                SELECT
                    ST_Multi(ST_Intersection(zaf.landuse_agricregions.the_geom, zaf.admin2_provs.the_geom)) AS the_geom,
                    zaf.landuse_agricregions."type",
                    prov_code
                  FROM
                    zaf.landuse_agricregions,
                    zaf.admin2_provs
                  WHERE
                    ST_Intersects(
                        ST_Buffer(zaf.landuse_agricregions.the_geom, 0.0),
                        ST_Buffer(zaf.admin2_provs.the_geom, 0.0)
                        )
                    AND
                      prov_code NOTNULL
                    AND
                      zaf.landuse_agricregions."type" = 'Grains'
                ) AS g
            WHERE
              ST_Intersects(ST_Buffer(f.the_geom, 0.0), ST_Buffer(g.the_geom, 0.0))
        ) AS h,
        (
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
        ) AS i(prov_code, cec)
      WHERE
        h.prov_code = i.prov_code
;

INSERT INTO zaf.crops_probspecs (
    the_geom,
    "year",
    "month",
    crop,
    prov_code,
    cec_probspec,
    hazard,
    local_probspec
  )
    SELECT
        h.the_geom,
        2016 AS "year",
        5 AS "month",
        'white maize' AS "crop",
        h.prov_code,
        i.cec,
        h.hazard,
        0
      FROM
        (
          SELECT
              ST_Multi(ST_Difference(g.the_geom, f.the_geom)) AS the_geom,
              g.prov_code,
              f.hazard
            FROM
              (
                SELECT
                    ST_Multi((ST_Dump(ST_Union(the_geom))).geom) AS the_geom,
                    'less dry' AS hazard
                  FROM
                    zaf.vci_1601_buffer
                  WHERE
                      vci = '< 0.15'
                    OR
                      vci = '0.25 - 0.35'
                    OR
                      vci = '0.15 - 0.25'
              ) AS f,
              (
                SELECT
                    ST_Multi(ST_Intersection(zaf.landuse_agricregions.the_geom, zaf.admin2_provs.the_geom)) AS the_geom,
                    zaf.landuse_agricregions."type",
                    prov_code
                  FROM
                    zaf.landuse_agricregions,
                    zaf.admin2_provs
                  WHERE
                      ST_Intersects(
                        ST_Buffer(zaf.landuse_agricregions.the_geom, 0.0),
                        ST_Buffer(zaf.admin2_provs.the_geom, 0.0)
                      )
                    AND
                      prov_code NOTNULL
                    AND
                      zaf.landuse_agricregions."type" = 'Grains'
              ) AS g
            WHERE
              ST_Intersects(ST_Buffer(f.the_geom, 0.0), ST_Buffer(g.the_geom, 0.0))
        ) AS h,
        (
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
        ) AS i(prov_code, cec)
      WHERE
        h.prov_code = i.prov_code
;

INSERT INTO zaf.crops_probspecs (
    the_geom,
    "year",
    "month",
    crop,
    prov_code,
    cec_probspec,
    hazard,
    local_probspec
  )
    SELECT
        h.the_geom,
        2016 AS "year",
        5 AS "month",
        'white maize' AS "crop",
        h.prov_code,
        i.cec,
        h.hazard,
        0
      FROM
        (
          SELECT
              ST_Multi(ST_Difference(g.the_geom, f.the_geom)) AS the_geom,
              g.prov_code,
              f.hazard
            FROM
              (
                SELECT
                    the_geom,
                    'less dry' AS hazard
                  FROM
                    zaf.vci_1601_buffer
              ) AS f,
              (
                SELECT
                    ST_Multi(ST_Intersection(zaf.landuse_agricregions.the_geom, zaf.admin2_provs.the_geom)) AS the_geom,
                    zaf.landuse_agricregions."type",
                    prov_code
                  FROM
                    zaf.landuse_agricregions,
                    zaf.admin2_provs
                  WHERE
                      ST_Intersects(
                        ST_Buffer(zaf.landuse_agricregions.the_geom, 0.0),
                        ST_Buffer(zaf.admin2_provs.the_geom, 0.0)
                      )
                    AND
                      prov_code NOTNULL
                    AND
                      zaf.landuse_agricregions."type" = 'Grains'
              ) AS g
            WHERE
              NOT ST_Intersects(ST_Buffer(j.the_geom, 0.0), ST_Buffer(k.the_geom, 0.0))
        ) AS h,
        (
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
        ) AS i(prov_code, cec)
      WHERE
        h.prov_code = i.prov_code
;

SELECT "year", "month", crop, prov_code, cec_probspec, hazard, local_probspec FROM zaf.crops_probspecs;
