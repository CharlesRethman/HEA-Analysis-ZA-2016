/*
 * Purpose: to remove the calculation of the total numbers of affected people and the total amounts
 * of their deficits across a geographical area and for all wealth/affected groups, for a specific
 * analysis (year, month).
 *
 */


SELECT E'This query will only work if you have specified a switch on the command line \nfor the \'analysis\' variable, using the syntax:\n\n-v analysis=M-YYYY\n\nwhere M is a one- or two-digit number representing the month of analysis (1 to \n12) and YYYY is a four-digit number representing the year of analysis.\n'::text AS "NOTICE";


-- Drop old indices and recreate them (to ensure they refreshed)
DROP INDEX IF EXISTS zaf.tbl_ofa_outcomes_year_month_idx;

CREATE INDEX tbl_ofa_outcomes_year_month_idx ON zaf.tbl_ofa_outcomes USING btree (ofa_year, ofa_month);

-- Remove any previous analyses outcome with the same date
DELETE FROM
  zaf.tbl_ofa_outcomes
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
