var XLSX = require('xlsx'), pg = require('pg');


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


ask("Password", /.+/, function(pword) {
    console.log("Your password (!) is: ", pword);
    var conString = 'postgres://Charles:' + pword + '@localhost:5432/albers_ea';
//    process.exit();
    var client = new pg.Client(conString);
    client.connect(function(err) {
      if(err) {
        return console.error('could not connect to postgres', err);
      }
      //Variable for storing all the spreadsheets data
      var lzAbbrevs = [
        {"name" : "za_fw", "sheets" : [0,1,2]},
        {"name" : "za_up", "sheets" : [0,1,2,3]},
        {"name" : "za1xx", "sheets" : [0,1,2,3]},
        {"name" : "za2xx", "sheets" : [0,1,2,3]},
        {"name" : "za3xx", "sheets" : [0,1,2,3]},
        {"name" : "zacni", "sheets" : [0,1,2,3]},
        {"name" : "zakhc", "sheets" : [0,1,2,3]},
        {"name" : "zalof", "sheets" : [0,1,2,3]},
        {"name" : "zaloi", "sheets" : [0,1,2,3]},
        {"name" : "zalrc", "sheets" : [0,1,2,3]},
        {"name" : "zammo", "sheets" : [1,2,3]},
        {"name" : "zancc", "sheets" : [0,1,2,3]},
        {"name" : "zanfl", "sheets" : [0,1,2,3]},
        {"name" : "zanoc", "sheets" : [0,1,2,3]},
        {"name" : "zaocc", "sheets" : [0,1,2,3]},
        {"name" : "zaolo", "sheets" : [0,1,2,3]},
        {"name" : "zasco", "sheets" : [0,1,2,3]},
        {"name" : "zaslc", "sheets" : [0,1,2,3]},
        {"name" : "zatgl", "sheets" : [0,1,2]},
      ];

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

      var wgAffected = {
        grants : "",
        noGrants : "_nogrants"
      }

      var deficit = {
        fpl : 'T30',
        lbpl : 'T31',
        ubpl : 'T32',
      //  resilience : 'T33',
        food : 'M31'
      };

      var outcome = {};
//      var sql = 'INSERT INTO zaf.tbl_ofa_results (ofa_year, ofa_month, threshold, lz_affected, ' +
//          'wg_affected, deficit) VALUES (';

      for (var i = 0; i < lzAbbrevs.length; i++) {
      //  console.log('../spreadsheets/' + lzFiles[i] + '_0.xlsx');
        for (var subLz in lzAffected) {
          for (var subWG in wgAffected) {
            console.log(lzAbbrevs[i].name + lzAffected[subLz].ext + wgAffected[subWG])
            /* Get the workbook */
            var workbook = XLSX.readFile('./spreadsheets/' + lzAbbrevs[i].name +
                lzAffected[subLz].ext + wgAffected[subWG] + '.xlsx');
            /* DO SOMETHING WITH workbook HERE */
            for (var j = 0; j < lzAbbrevs[i].sheets.length; j++) {
              var first_sheet_name = workbook.SheetNames[lzAbbrevs[i].sheets[j]];

              /* Get worksheet */
              var worksheet = workbook.Sheets[first_sheet_name];
              outcome = {};
              /* Find desired cell */
              for (var thres in deficit) {
                var desired_cell = worksheet[deficit[thres]];
                /* Get the value */
                var desired_value = desired_cell.v;
                  if (thres === 'food') {
                    outcome[thres] = Math.round(desired_value * 100, 0) + '%';
                  } else {
                    outcome[thres] = Math.round(desired_value, 0);
                  };

                  console.log(
                      thres + ' deficit of ' + lzAbbrevs[i].name + lzAffected[subLz].ext + wgAffected[subWG] +
                      ', ' + first_sheet_name + ' wg, is ' + outcome[thres]);
                  sql +=
              }
            }
//            client.query(sql, function(err, result))
            client.query('SELECT NOW() AS "theTime"', function(err, result) {
              if(err) {
                return console.error('error running query', err);
              }
              console.log(result.rows[0].theTime);
              //output: Tue Jan 15 2013 19:12:47 GMT-600 (CST)
              client.end();
            });
          }
        }
      }
    });
  });

//Connection string to Postgres
