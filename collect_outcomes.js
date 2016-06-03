if(typeof require !== 'undefined') XLSX = require('xlsx');
var pg = require('pg');
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
for (var i = 0; i < lzAbbrevs.length; i++) {
//  console.log('../spreadsheets/' + lzFiles[i] + '_0.xlsx');
  for (var propLz in lzAffected) {
    for (var propWg in wgAffected) {
      console.log(lzAffected[propLz].ext + wgAffected[propWg])
      var workbook = XLSX.readFile('./spreadsheets/' + lzAbbrevs[i].name + lzAffected[propLz].ext
          + wgAffected[propWg] + '.xlsx');
      /* DO SOMETHING WITH workbook HERE */
      for (var j = 0; j < lzAbbrevs[i].sheets.length; j++) {
        var first_sheet_name = workbook.SheetNames[lzAbbrevs[i].sheets[j]];
        var deficit = 'M31';
/*    var deficit[1] = 'T31';
        var deficit[2] = 'T32';
        var deficit[3] = 'T33';
        var deficit[4] = 'M31'; */

        /* Get worksheet */
        var worksheet = workbook.Sheets[first_sheet_name];

        /* Find desired cell */
        var desired_cell = worksheet[deficit];

        /* Get the value */
        var desired_value = desired_cell.v;

        var result = Math.round(desired_value * 100,0);

        console.log(
          'Deficit of ' + lzAbbrevs[i].name + lzAffected[propLz].ext + wgAffected[propWg] +
          ', ' + first_sheet_name + ' wg, is ' + result + '%');
    }
  }
}}
