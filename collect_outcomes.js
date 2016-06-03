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
      client.query('SELECT NOW() AS "theTime"', function(err, result) {
        if(err) {
          return console.error('error running query', err);
        }
        console.log(result.rows[0].theTime);
        //output: Tue Jan 15 2013 19:12:47 GMT-600 (CST)
        client.end();
      });
      //Variable for storing all the spreadsheets data
      var lzAbbrevs = [
        {"name" : "za_fw", code: 59050, "sheets" : [0,1,2]},
        {"name" : "za_up", code: 59800, "sheets" : [0,1,2,3]},
        {"name" : "za1xx", code: 59100, "sheets" : [0,1,2,3]},
        {"name" : "za2xx", code: 59200, "sheets" : [0,1,2,3]},
        {"name" : "za3xx", code: 59300, "sheets" : [0,1,2,3]},
        {"name" : "zacni", code: 59106, "sheets" : [0,1,2,3]},
        {"name" : "zakhc", code: 59208, "sheets" : [0,1,2,3]},
        {"name" : "zalof", code: 59301, "sheets" : [0,1,2,3]},
        {"name" : "zaloi", code: 59302, "sheets" : [0,1,2,3]},
        {"name" : "zalrc", code: 59206, "sheets" : [0,1,2,3]},
        {"name" : "zammo", code: 59210, "sheets" : [1,2,3]},
        {"name" : "zancc", code: 59304, "sheets" : [0,1,2,3]},
        {"name" : "zanfl", code: 59207, "sheets" : [0,1,2,3]},
        {"name" : "zanoc", code: 59202, "sheets" : [0,1,2,3]},
        {"name" : "zaocc", code: 59209, "sheets" : [0,1,2,3]},
        {"name" : "zaolo", code: 59107, "sheets" : [0,1,2,3]},
        {"name" : "zasco", code: 59305, "sheets" : [0,1,2,3]},
        {"name" : "zaslc", code: 59203, "sheets" : [0,1,2,3]},
        {"name" : "zatgl", code: 59105, "sheets" : [0,1,2]},
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
        fpl : {
          cell: 'T30',
          num: 1
        },
        lbpl : {
          cell : 'T31',
          num : 2
        },
        ubpl : {
          cell : 'T32',
          num : 3
        },
      //  resilience : 'T33',
        food : {
          cell : 'M31',
          num : 5
        }
      };

      var outcome = {};
      var d = new Date();
      var sqlString = 'INSERT INTO zaf.tbl_ofa_results (ofa_year, ofa_month, threshold, lz_affected, ' +
          'wg_affected, wg, deficit) VALUES \n'

      for (var i = 0; i < lzAbbrevs.length; i++) {
      //  console.log('../spreadsheets/' + lzFiles[i] + '_0.xlsx');
        for (var subLz in lzAffected) {
          for (var subWG in wgAffected) {
//            console.log(lzAbbrevs[i].name + lzAffected[subLz].ext + wgAffected[subWG])
            /* Get the workbook */
            var workbook = XLSX.readFile('./spreadsheets/' + lzAbbrevs[i].name +
                lzAffected[subLz].ext + wgAffected[subWG] + '.xlsx');
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

                  console.log(
                      thres + ' deficit of ' + lzAbbrevs[i].name + lzAffected[subLz].ext +
                      wgAffected[subWG] + ', ' + sheet_name + ' wg, is ' + outcome[thres]);
                  sqlString += lzAbbrevs[i].name +  '/' + sheet_name + ': (' + d.getFullYear() + ', ' + (d.getMonth() + 1) + ', ' +
                      deficit[thres].num + ', ' + subLz + ', ' + (lzAbbrevs[i].sheets[j] + 1) + ', ' +
                      subWG + ', ' + outcome[thres] + '),\n';
              }
            }
          }
        }
      }
      sqlString = sqlString.substring(0, sqlString.length - 2) + ';';
      console.log(sqlString);
    });
  });

//Connection string to Postgres
