DROP TABLE IF EXISTS zaf.buffer_vci;

DROP TABLE IF EXISTS zaf.buffer_asi;

CREATE TABLE zaf.buffer_vci (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  vci VARCHAR(15)
  )
;


CREATE TABLE zaf.buffer_asi (
  gid SERIAL PRIMARY KEY,
  the_geom GEOMETRY(MULTIPOLYGON, 201100),
  asi VARCHAR(15)
  )
;

INSERT INTO zaf.buffer_vci (
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
                vci_desc AS vci
              FROM
                zaf.veg_cond_idx_1512
              GROUP BY
                vci_desc
            ) AS f
          WHERE
            ST_Area(f.the_geom) > 11335000
        ) AS g
      GROUP BY
        g.vci
;

INSERT INTO zaf.buffer_asi (
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
                asi_desc AS asi
              FROM
                zaf.ag_stress_idx_16013
              GROUP BY
                asi_desc
            ) AS f
          WHERE
            ST_Area(f.the_geom) > 11335000
        ) AS g
      GROUP BY
        g.asi
;
