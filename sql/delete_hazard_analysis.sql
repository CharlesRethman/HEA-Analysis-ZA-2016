/*
 * Purpose: to construct a table of outcomes by Small Area, Wealth Group, Wealth Group Affected
 * Category (receive/don't receive social grants) and Thresholds that can be summarised with a pivot
 * table or filtered and joined to the Small Area layer (zaf.demog_sas) to be map the outcome.
 *
 * The pivot table will calculate total numbers of affected people and their deficits by admin area
 * an livelihood zone.
 *
 */

SELECT E'This query will only work if you have specified a switch on the command line \nfor the \'analysis\' variable, using the syntax:\n\n-v analysis=M-YYYY\n\nwhere M is a one- or two-digit number representing the month of analysis (1 to \n12) and YYYY is a four-digit number representing the year of analysis.\n'::text AS "NOTICE";

-- Indices, table creation and preparation transaction
BEGIN;

-- Indices, table creation and preparation transaction
DROP INDEX IF EXISTS zaf.demog_sas_ofa_year_month_idx;

CREATE INDEX demog_sas_ofa_year_month_idx ON zaf.demog_sas_ofa USING btree (ofa_year, ofa_month);


-- Remove records for the analysis specified in the :analysis variable (-v
-- analysis=M-YYYY in the command line where M is a number (1 to 12) representing the month of
-- analysis and YYYY is a four-digit number (1980 to current year) representing the year of
-- analysis)
DELETE FROM
	zaf.demog_sas_ofa
WHERE
 		ofa_year = (
			SELECT
				--Check that the month and year are not before 01-01-1980 or after the curent date. If so, force to the current month and year.
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


COMMIT;
