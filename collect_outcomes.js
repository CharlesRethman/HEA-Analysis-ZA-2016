
var XLSX = require('xlsx'), pg = require('pg');

/*
 * Get a password from stdin.
 * Adapted from <http://stackoverflow.com/a/10357818/122384>.
 *
 * @param prompt {String} Optional prompt. Default 'Password: '.
 * @param callback {Function} `function (cancelled, password)` where
 *      `cancelled` is true if the user aborted (Ctrl+C).
 * [CR]Added in nice fat bullet placeholders ('\u2022').
 * [CR]Fixed the backspace to trim off last placeholders and snip password string at end.
 * [CR]Fixed Ctrl-C to exit process (Quit).
 *
 */

function getPassword(prompt, callback) {
   var stdin = process.stdin, stdout = process.stdout
   if (callback === undefined) {
      callback = prompt;
      prompt = undefined;
   }
   if (prompt === undefined) {
      prompt = 'Password';
   }
   if (prompt) {
      stdout.write(prompt + ": ");
   }

   stdin.resume();
   stdin.setRawMode(true);
   stdin.resume();
   stdin.setEncoding('utf8');

   var password = '';
   stdin.on('data', function (ch) {
      ch = ch + '';
      switch (ch) {
      case '\n':
      case '\r':
      case '\u0004':
         // They've finished typing their password
         stdout.write('\n');
         stdin.setRawMode(false);
         stdin.pause();
         callback(false, password);
         break;
      case '\u0003':
         // Ctrl-C
         callback(true);
         stdout.write('\n'); // add a line and quit
         process.exit();
         break;
      case '\u007F':
         // Backspace: BS to backup, DEL to remove character (but moves one forward), so BS again
         if (password.length > 0) {
            stdout.write('\u0008');
            stdout.write('\u007F');
            stdout.write('\u0008');
            password = password.slice(0, password.length - 1); // snip the password one char at end
         }
         break;
      default:
         // Other password characters
         stdout.write('\u2022');
         password += ch;
         break;
     }
   });
}



/*
 * Get any other user input such as user name, required dates or yes/no options. Data format can
 * also be defined in the 'format' parameter (using a RegExp).
 *
 * @param question {String} Optional. Question to be asked on StdIn. If it ends in '?', ':' or ')'
 * it will be append with a space only; if it ends with anything else it will be appended with '? '.
 * Default 'Enter: '.
 * @param format {RegExp}. Displays format as a regexp to the user. Default `/\w+|\s+/`, any number
 * of alphanumeric or whitespace characters allowed, nothing not allowed (  ).
 * @param callback {Function}. `Function (cancelled, data)` where cancelled is true if user aborts
 * (Ctrl-C).
 *
 */

function ask(question, format, callback) {
   var stdin = process.stdin, stdout = process.stdout;
   if (question === undefined) stdout.write("Enter: ");
   else if (question.trim().slice(-1) == ':' || question.trim().slice(-1) == '?' || question.trim().slice(-1) == ')') stdout.write(question.trim() + ' ');
   else stdout.write(question + '? ');
   if (format === undefined) format = /\w+|\s+/;
   stdin.setEncoding('utf8');

   stdin.resume();
   stdin.once('data', function(data) {
      if (data.length > 1) {
         data = data.toString().trim();
      } else {
         data = data.toString();
      }
      if (data == '\u0003') {
         callback(true);
         stdout.write('\n'); // add a line and quit
         process.exit();
      }
      if (format.test(data)) {
         // clear any extraneous single characters in StdOut
         stdout.write('\u0008');
         stdout.write('\u007F');
         stdout.write('\u0008');
         callback(false, data);
      } else {
         stdout.write("It should match: "+ format +"\n");
         ask(question, format, callback);
      }
   });
}


/*
 * Function to read all the spreadsheet values and load them into an object, as well as creating an
 * SQL INSERT values query string for loading the spreadsheet outputs into a Postgres table.
 *
 * @param sqlString {string} Required. First part of SQL string to which the results from the
 * spreadsheet reads are appended in correct syntax and returned.
 * @param ofa {Array} Required. Two elements with numbers representing month ofa[0] ('1' = January)
 * and year ofa[1].
 *
 */

function readSpreadSheets(sqlString, ofa) {
   console.log('Reading spreadsheets...');

   // build an object containing info on analysis spreadsheets. 'name' is the LZ abbrev name in the spreadsheet file name, 'code' is the LZ code (for the DB table), 'wgs' array contains objects with worksheet numbers (in the spreadsheet) and WG IDs from tbl_wgs in each LZ analysis.
   var lzAbbrevs = [
      {
         name : "za_fw", code: 59050, wgs : [
            {sheet : 0, wg : 5},
            {sheet : 1, wg : 6},
            {sheet : 2, wg : 7}
         ]
      },
      {
         name : "za_up", code: 59800, wgs : [
            {sheet : 0, wg : 8},
            {sheet : 1, wg : 9},
            {sheet : 2, wg : 10},
            {sheet : 3, wg : 11}
         ]
      },
      {
         name : "za1xx", code: 59100, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "za2xx", code: 59200, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "za3xx", code: 59300, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zacni", code: 59106, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zakhc", code: 59208, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zalof", code: 59301, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zaloi", code: 59302, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zalrc", code: 59206, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zammo", code: 59210, wgs : [
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zancc", code: 59304, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zanfl", code: 59207, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zanoc", code: 59202, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zaocc", code: 59209, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zaolo", code: 59107, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zasco", code: 59305, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zaslc", code: 59203, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3},
            {sheet : 3, wg : 4}
         ]
      },
      {
         name : "zatgl", code: 59105, wgs : [
            {sheet : 0, wg : 1},
            {sheet : 1, wg : 2},
            {sheet : 2, wg : 3}
         ]
      },
   ];
   // Object with the LZ affectedness groupings.
   var lzAffected = {
      normal : {
         code : 0,
         ext : "_0"
      },
      drought : {
         code: 1,
         ext : "_1"
      }
   };
   // Object with the wealth group affectedness groupings.
   var wgAffected = {
      grants : "",
      noGrants : "_nogrants"
   }
   // Deficits object
   var deficit = {
      fpl : {
         cell: 'T30',
         num: 1,
         descr : 'FPL deficit'
      },
      lbpl : {
         cell : 'T31',
         num : 2,
         descr : 'LBPL deficit'
      },
      ubpl : {
         cell : 'T32',
         num : 3,
         descr : 'UBPL deficit'
      },
//        resilience : {
//          cell : 'T33',
//          num : 4,
//          descr : 'Resilience deficit'
//        },
      food : {
         cell : 'M31',
         num : 5,
         descr : 'Food energy deficit'
      }
   };

   var outcome = {};

   for (var i = 0; i < lzAbbrevs.length; i++) {
      for (var subLz in lzAffected) {
         for (var subWG in wgAffected) {
            // Get the workbook
            var workbook = XLSX.readFile('./spreadsheets/' + lzAbbrevs[i].name + lzAffected[subLz].ext + wgAffected[subWG] + '.xlsx');
            process.stdout.write('./spreadsheets/' + lzAbbrevs[i].name + lzAffected[subLz].ext +
            wgAffected[subWG] + '.xlsx\n');
            // Get the worksheet and assign it to a variable
            for (var j = 0; j < lzAbbrevs[i].wgs.length; j++) {
               var sheet_name = workbook.SheetNames[lzAbbrevs[i].wgs[j].sheet];
               var worksheet = workbook.Sheets[sheet_name];
               //reset the outcome object
               outcome = {};
               // Find desired cell
               for (var thres in deficit) {
                  var desired_cell = worksheet[deficit[thres].cell];
                  // Get the value
                  var desired_value = desired_cell.v;
                  if (thres === 'food') {
                     outcome[thres] = Math.round(desired_value * 100, 0) + '%';
                  } else {
                     outcome[thres] = Math.round(desired_value, 0);
                  };

                  sqlString += '(' + ofa[1] + ', ' + ofa[0] + ', ' + lzAbbrevs[i].code + ', ' + (lzAbbrevs[i].wgs[j].wg) + ', \u0027' + subLz + '\u0027, \u0027' + subWG + '\u0027, \u0027' + deficit[thres].descr + '\u0027, ' + desired_value + '),\n';
               }
            }
         }
      }
   }
   // Query SQL string for inserting data into zaf.tbl_ofa_analysis postgres table
   sqlString = sqlString.substring(0, sqlString.length - 2) + '\n;';
//   console.log(sqlString);
   return sqlString
}



/*
 * Get the database time. Simple routine to throw out the time on the Database when the update
 * (INSERT or DELETE) is finished.
 *
 * @param pgClient {Object}. Required. Postgres client connection object must be passed.
 *
 */

function getDbTime(pgClient) {
  // Query to get a time stamp from the DB(!) for the succesful completion of the work
  pgClient.query('SELECT NOW() AS "theTime"', function(err, result) {
    if(err) {
      return console.error('error running query', err);
    }
    // Success. Output is something like Tue Jun 21 2016 10:12:47 GMT+0200 (SAST)
    console.log(result.rows[0].theTime);
    // end client session*/
    pgClient.end();
    process.exit();
    });

}

/*
 * Deletes previous record for the same analysis date and uploads the current analysis results
 * collected from the spreadsheets.
 *
 * @param pgClient {Object}. Required. Postgres client connection object must be passed.
 * @param ofa {Array} Required. Two elements with numbers representing month ofa[0] ('1' = January)
 * and year ofa[1].
 * @param deleteOnly {Boolean}. Optional. TRUE when data for analysis are deleted but not reinserted.
 * Default FALSE.
 *
 */

function loadTable(pgClient, ofa, deleteOnly) {
   // Query to first delete existing data in zaf.tbl_ofa_analysis for the desired month and year
   pgClient.query('DELETE FROM zaf.tbl_ofa_analysis WHERE ofa_year = ' + ofa[1] + ' AND ofa_month = ' + ofa[0] + ';', function(err, result) {
      if(err) {
         return console.error('error running DELETE query', err);
      }
      // Success. Output is something like DELETE: 1168 rows affected
      console.log(result.command + ': ' + result.rowCount + ' rows affected');
      // Query to insert the new data using the SQL string above
      if (!deleteOnly) {
         // Create the INSERT SQL String
         var sqlString = 'INSERT INTO zaf.tbl_ofa_analysis (ofa_year, ofa_month, lz_code, wg_code, ' + 'lz_affected, wg_affected, threshold, deficit) VALUES \n';
         sqlString = readSpreadSheets(sqlString, ofa);
         pgClient.query(sqlString, function(err, result) {
            if(err) {
               return console.error('error running INSERT query', err);
            }
            // Success. Output is something like INSERT: 1168 rows affected
            console.log(result.command + ': ' + result.rowCount + ' rows affected');
            getDbTime(pgClient);
         });
      } else {
         getDbTime(pgClient);
      }
   });
}


/*
 * Connects to the DB and selects which analysis (month, year) the user wants load into it.
 *
 * @param pgClient {Object}. Required. Postgres client object with connection string credentials in
 * it must be passed.
 *
 */

function connectDB(pgClient) {
   // Connect the client to the database
   pgClient.connect(function(err) {
      if(err) {
         return console.error('could not connect to postgres', err);
      }
      // Query the database to find out how many analyses have been done before
      pgClient.query('SELECT ofa_month, ofa_year, count(*) AS result FROM zaf.tbl_ofa_analysis GROUP BY ofa_year, ofa_month ORDER BY ofa_year, ofa_month;', function(err, result) {
         if(err) {
            return console.error('error retrieving analyses', err);
         }
         // Success
         var months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
         console.log('\nYour existing analysis are:');
         console.log('OFA Month | OFA Year |   results\n----------+----------+-----------');
         for (i = 0; i < result.rowCount; i++) {
            var pad_month = '';
            var pad_result = '';
            for (j = 0; j < 9 - (months[result.rows[i].ofa_month - 1]).length; j++) pad_month+= ' ';
            for (j = 0; j < 10 - (' ' + result.rows[i].result).length; j++) pad_result += ' ';
            console.log(months[result.rows[i].ofa_month - 1] + pad_month + ' |     ' + result.rows[i].ofa_year + ' | ' + pad_result + result.rows[i].result);
         }
         console.log('----------+----------+-----------');
         // Get the month and year of the analysis
         ask('Which month and year of analysis do you want to assign to these spreadsheets?\nType it in as numbers representing M-YYYY (e.g. 9-2013 or 11-2015) ', /\d{1,2}-\d{4}/, function(cancel, analysisMonth) {
            if (!cancel) {
               var d = new Date(), check = false, deleteOnly = false;
               var ofa = analysisMonth.split('-');
               // Force to current month and year if supplied values are out of range
               if (ofa[0] * 1 > 12) ofa[0]= 12;
               if (ofa[0] * 1 < 1) ofa[0] = 1;
               if (new Date(ofa[1], ofa[0]-1, 1) > d || ofa[1] * 1 < 1980 ) {
                  ofa[0] = d.getMonth() + 1;
                  ofa[1] = d.getFullYear();
                  console.log('Analysis reset to ' + ofa[0] + '-' + ofa[1] + '; it cannot be ahead of time or before 1980.');
               }
               for (i = 0; i < result.rowCount; i++) {
                  if (ofa[0] == result.rows[i].ofa_month && ofa[1] == result.rows[i].ofa_year) {
                     var check = true;
                     break;
                  }
               }
               if (check) {
                  ask('This analysis already exists. Delete only (yes - just delete / no - delete and\nreinsert data)?', /.+/, function(cancel, justDel) {
                     if (!cancel) {
                        if (justDel.toUpperCase() == 'Y' || justDel.toUpperCase() == 'YES') deleteOnly = true
                        ask('Are you REALLY sure you want to delete all your previous data for ' + months[ofa[0] - 1] + ' ' + ofa[1] + '\n(yes - proceed / no - quit before affecting anything)?', /.+/, function(cancel, confirm) {
                           if (!cancel) {
                              if (confirm.toUpperCase() == 'Y' || confirm.toUpperCase() == 'YES') {
                                 // Call the loadTable function
                                 loadTable(pgClient, ofa, deleteOnly);
                              } else {
                                 pgClient.end();
                                 process.exit();
                              }
                           }
                        });
                     }
                  });
               } else {
                  loadTable(pgClient, ofa, false);
               }
            }
         });
      });
   });
}



/*
 * Callers for getting user inputs for connecting to the database. Upon entry of credentials, the
 * `connectDB` function is called with the a client object for connecting to the database. No
 * authentication/authorisation at this stage.
 *
 */

// Get the user name
ask('\nYou may need account credentials to connect to Postgres. However, if you\ndownloaded the database dump file from GitHub, you may ignore the user name\nand password below (skip by pressing ENTER twice)\n\nPostgres user name', /.+|\s/, function(cancel, user_name) {
   if (!cancel) {
      // Get the DB password
      getPassword('Postgres password', function(cancel, password) {
         // pass the user name and password as a connection string onto Postgres in the main data
         // processing function
         if (!cancel) {
            var client = new pg.Client('postgres://' + user_name + ':' + password + '@localhost:5432/albers_ea');
            // Go through to slecting the month and year of analysis
            connectDB(client);
         }
      });
   }
});
