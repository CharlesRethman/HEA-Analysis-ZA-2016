DROP TABLE IF EXISTS zaf.tbl_lz_mapping;

CREATE TABLE zaf.tbl_lz_mapping (
  lz_code integer primary key,
  lz_analysis_code integer
  )
;

INSERT INTO zaf.tbl_lz_mapping (
  lz_code,
  lz_analysis_code
  )
    SELECT
      f.lz_code,
      f.lz_code
    FROM
      zaf.tbl_livezones_list AS f,
      (SELECT lz_code FROM zaf.tbl_ofa_outcomes GROUP BY lz_code) AS g
    WHERE
      f.lz_code = g.lz_code

    UNION
    -- farm workers
    SELECT
      lz_code,
      59050
    FROM
      zaf.tbl_livezones_list AS h
    WHERE
        h.lz_code < 59700
      AND
        TO_NUMBER (substring (TO_CHAR (h.lz_code, '99999') FROM 4 FOR 1), '9') < 6
      AND
        TO_NUMBER (substring (TO_CHAR (h.lz_code, '99999') FROM 5 FOR 1), '9') > 4

    UNION
    -- other open access zones
    SELECT
      lz_code,
      TO_NUMBER('59' || substring (TO_CHAR (i.lz_code, '99999') FROM 4 FOR 1) || '00', '99999')
    FROM
      zaf.tbl_livezones_list AS i
    WHERE
        i.lz_code < 59350
      AND
        TO_NUMBER (substring (TO_CHAR (i.lz_code, '99999') FROM 5 FOR 1), '9') < 5
      AND
        lz_code NOT IN (
          SELECT
            j.lz_code
          FROM
            zaf.tbl_livezones_list AS j,
            (SELECT lz_code FROM zaf.tbl_ofa_outcomes GROUP BY lz_code) AS k
          WHERE
            k.lz_code = j.lz_code
          )

    UNION
    -- urban
    SELECT
      lz_code,
      59899
    FROM
      zaf.tbl_livezones_list
    WHERE
        (lz_code > 59810 AND lz_code < 59860)
      OR
        (lz_code > 59700 AND lz_code < 59800)

;


SELECT * FROM zaf.tbl_lz_mapping ORDER BY lz_code;
