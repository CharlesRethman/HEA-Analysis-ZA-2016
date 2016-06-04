DROP TABLE IF EXISTS zaf.tbl_pop_proj;
DROP TABLE IF EXISTS zaf.tmp_pop_proj;


BEGIN;
CREATE TABLE zaf.tbl_pop_proj (
  "tid" serial primary key,
  district varchar(6),
  dc_name varchar(100),
  sex varchar(6),
  age varchar(7),
  year_mid integer,
  pop integer
  )
;

CREATE TABLE zaf.tmp_pop_proj (
  "tid" serial primary key,
  "name" varchar(100),
  sex varchar(6),
  age varchar(7),
  "2002" integer,
  "2003" integer,
  "2004" integer,
  "2005" integer,
  "2006" integer,
  "2007" integer,
  "2008" integer,
  "2009" integer,
  "2010" integer,
  "2011" integer,
  "2012" integer,
  "2013" integer,
  "2014" integer,
  "2015" integer,
  "2016" integer
  )
;

COPY zaf.tmp_pop_proj (
    "name",
    sex,
    age,
    "2002",
    "2003",
    "2004",
    "2005",
    "2006",
    "2007",
    "2008",
    "2009",
    "2010",
    "2011",
    "2012",
    "2013",
    "2014",
    "2015",
    "2016"
  )
  FROM
    '/Users/Charles/Documents/hea_analysis/south_africa/2016.04/pop/dc_projection_by_sex_and_age_2002-2015.csv'
  WITH (
    FORMAT CSV,
    DELIMITER ',',
    HEADER TRUE
  )
;

UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (CPT)'
  WHERE "name" = 'WC - City of Cape Town Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (BUF)'
  WHERE "name" = 'EC - Buffalo City Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (NMA)'
  WHERE "name" = 'EC - Nelson Mandela Bay Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (ETH)'
  WHERE "name" = 'KZN - eThekwini Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (JHB)'
  WHERE "name" = 'GT - City of Johannesburg Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (EKU)'
  WHERE "name" = 'GT - Ekurhuleni Metropolitan Municipality';
UPDATE zaf.tmp_pop_proj
  SET "name" = "name" || ' (TSH)'
  WHERE "name" = 'GT - City of Tshwane Metropolitan Municipality';

--create or replace the function that loops to create line dashes that run
CREATE OR REPLACE FUNCTION zaf.load_pop_projs(
	start_year integer,									--the year that the projection data begins with
	curr_year integer)									--the current year, the last year of the projection series
RETURNS text                          --Brings back a list of the INSERT queries SQL texts
AS $BODY$

DECLARE
	i integer;                          --counter
  qry_string text;                    --INSERT query that must be executed repeatedly
  queries text;
BEGIN
  queries := '';
  i := start_year;
  <<do_insert>>
  LOOP
    IF i > curr_year THEN
      EXIT;
    ELSE
      qry_string :=
          'INSERT INTO zaf.tbl_pop_proj (district, dc_name, sex, age, '
              || 'year_mid, pop) SELECT '
              || 'substr("name", strpos("name", ' || quote_literal('(')
              || ') + 1, abs(strpos("name", ' || quote_literal(')')
              || ') - strpos("name", ' || quote_literal('(') || ' ) - 1)) AS '
              || 'district, "name", sex, age, ' || i || ' AS year_mid, "'
              || i || '" FROM zaf.tmp_pop_proj ORDER BY district, sex DESC, '
              || 'to_number(age, ' || quote_literal('99') || ')::integer;';
      queries := queries || E'\n' || qry_string;
      RAISE NOTICE 'qry_string = %', qry_string;
      i := i + 1;
      EXECUTE qry_string;
    END IF;
  END LOOP do_insert;
  RETURN queries;
END;
$BODY$
  LANGUAGE plpgsql;

SELECT zaf.load_pop_projs(
    2002,
    CAST(EXTRACT(YEAR FROM current_date) AS integer)
  )::text
;


DROP TABLE IF EXISTS zaf.tmp_pop_proj;
COMMIT;
