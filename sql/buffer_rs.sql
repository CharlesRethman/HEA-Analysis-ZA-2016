/*
 * PURPOSE: To create a single polygon or a group of polygons describing the worst affected areas,
 * after a raster image has been 'polygonised'.
 *
 */


DROP TABLE IF EXISTS zaf.rs_vci_16_01_buffer;
DROP TABLE IF EXISTS zaf.rs_asi_16_01_3_buffer;

DROP INDEX IF EXISTS zaf.rs_vci_16_01_the_geom_gidx;
DROP INDEX IF EXISTS zaf.rs_asi_16_01_3_the_geom_gidx;

CREATE INDEX rs_vci_16_01_the_geom_gidx ON zaf.rs_vci_16_01 USING GIST(the_geom);
CREATE INDEX rs_asi_16_01_3_the_geom_gidx ON zaf.rs_asi_16_01_3 USING GIST(the_geom);

BEGIN;

CREATE TABLE zaf.rs_vci_16_01_buffer (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  vci VARCHAR(15)
  )
;


CREATE TABLE zaf.rs_asi_16_01_3_buffer (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  asi VARCHAR(15)
  )
;

INSERT INTO zaf.rs_vci_16_01_buffer (
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
                zaf.rs_vci_16_01
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

INSERT INTO zaf.rs_asi_16_01_3_buffer (
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
                zaf.rs_asi_16_01_3
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
