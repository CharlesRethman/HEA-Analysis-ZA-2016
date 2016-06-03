var XLSX = require('xlsx'), pg = require('pg');

/**
 * Get a password from stdin.
 *
 * Adapted from <http://stackoverflow.com/a/10357818/122384>.
 *
 * @param prompt {String} Optional prompt. Default 'Password: '.
 * @param callback {Function} `function (cancelled, password)` where
 *      `cancelled` is true if the user aborted (Ctrl+C).
 *
 * Limitations: Not sure if backspace is handled properly.
 */
function getPassword(prompt, callback) {
    if (callback === undefined) {
        callback = prompt;
        prompt = undefined;
    }
    if (prompt === undefined) {
        prompt = 'Password: ';
    }
    if (prompt) {
        process.stdout.write(prompt);
    }

    var stdin = process.stdin;
    stdin.resume();
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding('utf8');

    var password = '';
    stdin.on('data', function (ch) {
        ch = ch + "";
        switch (ch) {
        case "\n":
        case "\r":
        case "\u0004":
            // They've finished typing their password
            process.stdout.write('\n');
            stdin.setRawMode(false);
            stdin.pause();
            callback(false, password);
            break;
        case '\u0003':
            // Ctrl-C
            callback(true);
            break;
        case '\u007F':
            // backspace
            process.stdout.write('\u0008');
//            process.stdout.write('\u007F');
            password = password.substring(0, password.length - 1);
            break;
        default:
            // More password characters
            process.stdout.write('\u2022');
            password += ch;
            break;
        }
    });
}




function ask(question, format, callback) {
 var stdin = process.stdin, stdout = process.stdout;

 stdin.resume();
 stdout.write(question + ": ");

 stdin.once('data', function(data) {
   data = data.toString().trim();

   if (format.test(data)) {
     callback(data);
   } else {
     stdout.write("It should match: "+ format +"\n");
     ask(question, format, callback);
   }
 });
}

function toUnicode(theString) {
  var unicodeString = '';
  for (var i=0; i < theString.length; i++) {
    var theUnicode = theString.charCodeAt(i).toString(16).toUpperCase();
    while (theUnicode.length < 4) {
      theUnicode = '0' + theUnicode;
    }
    theUnicode = '\\u' + theUnicode;
    unicodeString += theUnicode;
  }
  return unicodeString;
}

/* caller for getting any parameters */
//ask("Password", /.+/, function(your_input) {
/*  ....do stuff here ...  */
//  console.log("Your input is: ", your input);
//  process.exit();
//});

// Main callback function to connect to the DB, read spreadsheets and upload the results.
// Get the DB password
getPassword('Enter Postgres password: ', function(err, pword) {

    console.log('Your password is: ' + toUnicode(pword));
    var conString = 'postgres://Charles:' + pword + '@localhost:5432/albers_ea';
    var client = new pg.Client(conString);
    client.connect(function(err) {
      if(err) {
        return console.error('could not connect to postgres', err);
      }
      // continue
      process.stdout.write('Reading spread sheets...\n');

      // Object containing info on analysis spreadsheets.
      // 'name' is the LZ name in the spreadsheet, 'code' is the LZ code (for the DB table), 'sheets'
      // are the worksheets containg the analysis.
      var lzAbbrevs = [
        {name : "za_fw", code: 59050, sheets : [0,1,2]},
        {name : "za_up", code: 59800, sheets : [0,1,2,3]},
        {name : "za1xx", code: 59100, sheets : [0,1,2,3]},
        {name : "za2xx", code: 59200, sheets : [0,1,2,3]},
        {name : "za3xx", code: 59300, sheets : [0,1,2,3]},
        {name : "zacni", code: 59106, sheets : [0,1,2,3]},
        {name : "zakhc", code: 59208, sheets : [0,1,2,3]},
        {name : "zalof", code: 59301, sheets : [0,1,2,3]},
        {name : "zaloi", code: 59302, sheets : [0,1,2,3]},
        {name : "zalrc", code: 59206, sheets : [0,1,2,3]},
        {name : "zammo", code: 59210, sheets : [1,2,3]},
        {name : "zancc", code: 59304, sheets : [0,1,2,3]},
        {name : "zanfl", code: 59207, sheets : [0,1,2,3]},
        {name : "zanoc", code: 59202, sheets : [0,1,2,3]},
        {name : "zaocc", code: 59209, sheets : [0,1,2,3]},
        {name : "zaolo", code: 59107, sheets : [0,1,2,3]},
        {name : "zasco", code: 59305, sheets : [0,1,2,3]},
        {name : "zaslc", code: 59203, sheets : [0,1,2,3]},
        {name : "zatgl", code: 59105, sheets : [0,1,2]},
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
      var d = new Date();
      var sqlString = 'INSERT INTO zaf.tbl_ofa_results (ofa_year, ofa_month, lz_code, wg_code, ' +
          'lz_affected, wg_affected, threshold, deficit) VALUES \n'

      for (var i = 0; i < lzAbbrevs.length; i++) {
        for (var subLz in lzAffected) {
          for (var subWG in wgAffected) {
            /* Get the workbook */
            var workbook = XLSX.readFile('./spreadsheets/' + lzAbbrevs[i].name +
                lzAffected[subLz].ext + wgAffected[subWG] + '.xlsx');
            process.stdout.write('./spreadsheets/' + lzAbbrevs[i].name + lzAffected[subLz].ext +
                wgAffected[subWG] + '.xlsx\n');
            /* DO SOMETHING WITH workbook HERE */
            for (var j = 0; j < lzAbbrevs[i].sheets.length; j++) {
              var sheet_name = workbook.SheetNames[lzAbbrevs[i].sheets[j]];

              /* Get worksheet */
              var worksheet = workbook.Sheets[sheet_name];
              outcome = {};
              /* Find desired cell */
              for (var thres in deficit) {
                var desired_cell = worksheet[deficit[thres].cell];
                /* Get the value */
                var desired_value = desired_cell.v;
                  if (thres === 'food') {
                    outcome[thres] = Math.round(desired_value * 100, 0) + '%';
                  } else {
                    outcome[thres] = Math.round(desired_value, 0);
                  };

//                  console.log(
//                      thres + ' deficit of ' + lzAbbrevs[i].name + lzAffected[subLz].ext +
//                      wgAffected[subWG] + ', ' + sheet_name + ' wg, is ' + outcome[thres]);
                  sqlString += '(' + d.getFullYear() + ', ' + (d.getMonth() + 1) + ', ' +
                      lzAbbrevs[i].code + ', ' + (lzAbbrevs[i].sheets[j] + 1) + ', \u0027' + subLz +
                      '\u0027, \u0027' + subWG + '\u0027, \u0027' + deficit[thres].descr +
                      '\u0027, ' + desired_value + '),\n';
              }
            }
          }
        }
      }
      //Connection string to Postgres
      sqlString = sqlString.substring(0, sqlString.length - 2) + '\n;';
      console.log(sqlString);
      client.query(sqlString, function(err, result) {
        if(err) {
          return console.error('error running query', err);
        }
        console.log(result.command + ': ' + result.rowCount + ' rows affected');
      });
      client.query('SELECT NOW() AS "theTime"', function(err, result) {
        if(err) {
          return console.error('error running query', err);
        }
        console.log(result.rows[0].theTime);
        //output: Tue Jan 15 2013 19:12:47 GMT-600 (CST)
        client.end();
      });
    });
//    process.exit();
});
