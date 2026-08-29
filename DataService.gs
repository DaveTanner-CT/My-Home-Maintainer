function PDS_getSpreadsheet_() {
  const id = PDS_getConfig_().spreadsheetId;
  if (!id) throw new Error('The Petite Design Studio data spreadsheet is not configured.');
  return SpreadsheetApp.openById(id);
}

function PDS_getSheet_(sheetName) {
  const sheet = PDS_getSpreadsheet_().getSheetByName(sheetName);
  if (!sheet) throw new Error('Missing data sheet: ' + sheetName);
  return sheet;
}

function PDS_getHeaders_(sheetName) {
  const sheet = PDS_getSheet_(sheetName);
  const lastColumn = sheet.getLastColumn();
  if (!lastColumn) return [];
  return sheet.getRange(1,1,1,lastColumn).getValues()[0].map(String);
}

function PDS_getRecords_(sheetName) {
  const sheet = PDS_getSheet_(sheetName);
  const lastRow = sheet.getLastRow();
  const lastColumn = sheet.getLastColumn();
  if (lastRow < 2 || lastColumn < 1) return [];
  const headers = sheet.getRange(1,1,1,lastColumn).getValues()[0].map(String);
  const values = sheet.getRange(2,1,lastRow-1,lastColumn).getValues();
  return values.map(row => {
    const record = {};
    headers.forEach((header,i) => record[header] = row[i]);
    return record;
  });
}

function PDS_appendRecord_(sheetName, record) {
  const sheet = PDS_getSheet_(sheetName);
  const headers = PDS_getHeaders_(sheetName);
  const row = headers.map(header => Object.prototype.hasOwnProperty.call(record, header) ? record[header] : '');
  sheet.appendRow(row);
  return record;
}

function PDS_findRecord_(sheetName, keyField, keyValue) {
  return PDS_getRecords_(sheetName).find(record => String(record[keyField]) === String(keyValue)) || null;
}

function PDS_updateRecord_(sheetName, keyField, keyValue, updates) {
  const sheet = PDS_getSheet_(sheetName);
  const values = sheet.getDataRange().getValues();
  if (!values.length) return null;
  const headers = values[0].map(String);
  const keyIndex = headers.indexOf(keyField);
  if (keyIndex < 0) throw new Error('Missing key field ' + keyField + ' in ' + sheetName);
  let targetRow = -1;
  for (let r = 1; r < values.length; r++) {
    if (String(values[r][keyIndex]) === String(keyValue)) { targetRow = r + 1; break; }
  }
  if (targetRow < 0) throw new Error('Record not found in ' + sheetName + ': ' + keyValue);
  const row = values[targetRow - 1].slice();
  Object.keys(updates || {}).forEach(field => {
    const index = headers.indexOf(field);
    if (index >= 0) row[index] = updates[field];
  });
  sheet.getRange(targetRow,1,1,headers.length).setValues([row]);
  const result = {};
  headers.forEach((header,i) => result[header] = row[i]);
  return result;
}
