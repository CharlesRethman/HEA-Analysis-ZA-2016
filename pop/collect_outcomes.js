if(typeof require !== 'undefined') XLSX = require('xlsx');
var lzFiles = [
  'za_fw',
  'za_up',
  'za1xx',
  'za2xx',
  'za3xx',
  'zacni',
  'zakhc',
  'zalof',
  'zaloi',
  'zalrc',
  'zammo',
  'zancc',
  'zanfl',
  'zanoc',
  'zaocc',
  'zaolo',
  'zasco',
  'zaslc',
  'zatgl'
]
for (var i = 0; i < lzFiles.length; i++) {
//  console.log('../spreadsheets/' + lzFiles[i] + '_0.xlsx');
  var workbook = XLSX.readFile('../spreadsheets/' + lzFiles[i] + '_0.xlsx');
  /* DO SOMETHING WITH workbook HERE */
  for (var j = 0; j < 4; j++) {
    var first_sheet_name = workbook.SheetNames[j];
    var deficit = 'M31';

    /* Get worksheet */
    var worksheet = workbook.Sheets[first_sheet_name];

    /* Find desired cell */
    var desired_cell = worksheet[deficit];

    /* Get the value */
    var desired_value = desired_cell.v;

    var result = Math.round(desired_value * 100,0);

    console.log('Deficit of ' + lzFiles[i] + ', ' + first_sheet_name + ' wg, is ' + result + '%');
  }
}
