DROP TABLE IF EXISTS zaf.vci_1601_buffer;
DROP TABLE IF EXISTS zaf.asi_16013_buffer;

DROP INDEX IF EXISTS zaf.veg_cond_idx_1601_gidx;
DROP INDEX IF EXISTS zaf.ag_stress_idx_2016013_gidx;

CREATE INDEX veg_cond_idx_1601_gidx ON zaf.veg_cond_idx_1601 USING GIST(the_geom);
CREATE INDEX ag_stress_idx_2016013_gidx ON zaf.ag_stress_idx_2016013 USING GIST(the_geom);

BEGIN;

CREATE TABLE zaf.vci_1601_buffer (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  vci VARCHAR(15)
  )
;


CREATE TABLE zaf.asi_16013_buffer (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  asi VARCHAR(15)
  )
;

INSERT INTO zaf.vci_1601_buffer (
  the_geom,
  vci
  )
    SELECT
        ST_Multi((ST_Dump(ST_Union(ST_Buffer(g.the_geom, 1500)))).geom),
        g.vci AS vci
      FROM (
        SELECT
            ST_Multi(f.the_geom) AS the_geom,
            f.vci
          FROM (
            SELECT
                (ST_Dump(ST_Union(the_geom))).geom AS the_geom,
                vci
              FROM
                zaf.veg_cond_idx_1601
              GROUP BY
                vci
            ) AS f
          WHERE
            ST_Area(f.the_geom) > 50000000
        ) AS g
      WHERE
        ST_Within(
            g.the_geom,
            ST_PolygonFromText(
                'POLYGON((-900000 -750000, -900000 770000, 870000 770000, 870000 -750000, -900000 -750000))',
                201100
              )
          )
      GROUP BY
        g.vci
;

INSERT INTO zaf.asi_16013_buffer (
  the_geom,
  asi
  )
    SELECT
        ST_Multi((ST_Dump(ST_Union(ST_Buffer(g.the_geom, 1500)))).geom),
        g.asi AS asi
      FROM (
        SELECT
            ST_Multi(f.the_geom) AS the_geom,
            f.asi
          FROM (
            SELECT
                (ST_Dump(ST_Union(the_geom))).geom AS the_geom,
                asi
              FROM
                zaf.ag_stress_idx_16013
              GROUP BY
                asi
            ) AS f
          WHERE
            ST_Area(f.the_geom) > 11335000
        ) AS g
      WHERE
        ST_Within(
            g.the_geom,
            ST_PolygonFromText(
                'POLYGON((-900000 -750000, -900000 770000, 870000 770000, 870000 -750000, -900000 -750000))',
                201100
              )
          )
      GROUP BY
        g.asi
;

COMMIT;
