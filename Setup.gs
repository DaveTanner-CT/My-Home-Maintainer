const PDS_SETUP_SPREADSHEET_ID = '';
const PDS_SETUP_PROJECT_ROOT_FOLDER_ID = '';

function PDS_runInitialSetup() {
  PDS_saveInitialConfiguration_();
  PDS_initializeDataModel();
}

function PDS_saveInitialConfiguration_() {
  const props = PropertiesService.getScriptProperties();
  if (PDS_SETUP_SPREADSHEET_ID) props.setProperty(PDS.PROPERTY_KEYS.SPREADSHEET_ID, PDS_SETUP_SPREADSHEET_ID);
  if (PDS_SETUP_PROJECT_ROOT_FOLDER_ID) props.setProperty(PDS.PROPERTY_KEYS.PROJECT_ROOT_FOLDER_ID, PDS_SETUP_PROJECT_ROOT_FOLDER_ID);
}

function PDS_initializeDataModel() {
  const schemas = PDS_getSchemas_();
  Object.keys(schemas).forEach(name => PDS_ensureSheetSchema_(name, schemas[name]));
  PDS_seedSettings_();
}

function PDS_getSchemas_() {
  return {
    Settings: ['SettingKey','SettingValue','Notes'],
    Users: ['UserID','Email','DisplayName','Role','Active','CreatedDate','LastUpdatedDate'],
    Clients: ['ClientID','FirstName','LastName','PreferredName','Email','Phone','PropertyAddress','BillingAddress','PreferredCommunicationMethod','ReferralSource','Notes','CreatedDate','LastUpdatedDate','Active'],
    Projects: ['ProjectID','ClientID','ProjectName','PropertyAddress','ScopeSummary','ProjectStatus','InquiryDate','ConsultationDate','TargetStartDate','TargetCompletionDate','ActualCompletionDate','LeadDesigner','DriveFolderID','InternalNotes','ClientFacingNotes','CreatedDate','LastUpdatedDate','Archived'],
    Rooms: ['RoomID','ProjectID','RoomName','RoomType','SortOrder','Notes','CreatedDate','LastUpdatedDate'],
    DesignRecords: ['DesignRecordID','ProjectID','RoomID','RecordType','Title','Description','DriveFileID','OriginalDesignRecordID','ParentDesignRecordID','VersionNumber','CreatedDate','CreatedBy','LastModifiedDate','ClientVisible','Notes'],
    Measurements: ['MeasurementID','ProjectID','RoomID','DesignRecordID','MeasurementType','Label','Value','Unit','Notes','CreatedDate','CreatedBy'],
    Estimates: ['EstimateID','ProjectID','EstimateVersion','CreatedDate','SentDate','ApprovalDate','Status','EstimatedCost','TargetMargin','SuggestedSellingPrice','OverrideSellingPrice','FinalProposedPrice','EstimatedProfit','EstimatedMargin','Notes'],
    EstimateItems: ['EstimateItemID','EstimateID','ProjectID','RoomID','DesignRecordID','ItemName','Description','Category','Quantity','UnitCost','EstimatedCost','VendorID','ProductURL','ImageDriveFileID','ClientPrice','Taxable','SortOrder','Notes'],
    Vendors: ['VendorID','BusinessName','ContactName','Email','Phone','Website','Address','VendorType','AccountNumber','TradeDiscountInformation','Notes','Active','CreatedDate','LastUpdatedDate'],
    Expenses: ['ExpenseID','ProjectID','RoomID','EstimateItemID','VendorID','ExpenseDate','Category','Description','AmountBeforeTax','Tax','Shipping','TotalExpense','ReceiptDriveFileID','PaymentMethod','TaxCategory','Reimbursable','Notes','CreatedDate','CreatedBy'],
    Invoices: ['InvoiceID','ProjectID','InvoiceNumber','InvoiceDate','DueDate','InvoiceAmount','InvoiceType','Status','PDFDriveFileID','SentDate','Notes','CreatedDate'],
    Payments: ['PaymentID','ProjectID','InvoiceID','PaymentDate','Amount','PaymentMethod','ReferenceNumber','Notes','CreatedDate'],
    ChangeOrders: ['ChangeOrderID','ProjectID','ChangeOrderNumber','Description','AddedCost','RemovedCost','ClientPriceAdjustment','DateSubmitted','DateApproved','ApprovalStatus','ClientApprovalRecord','PDFDriveFileID','Notes','CreatedDate'],
    Files: ['FileID','ProjectID','RoomID','RelatedEntityType','RelatedEntityID','FileType','DisplayName','DriveFileID','DriveURL','CreatedDate','CreatedBy','ClientVisible','Notes'],
    Communications: ['CommunicationID','ProjectID','ClientID','CommunicationDate','Type','Subject','Summary','Direction','GmailMessageID','CreatedBy'],
    ActivityLog: ['ActivityID','Timestamp','UserEmail','ProjectID','EntityType','EntityID','Action','Description']
  };
}

function PDS_ensureSheetSchema_(sheetName, headers) {
  const ss = PDS_getSpreadsheet_();
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) sheet = ss.insertSheet(sheetName);
  const existing = sheet.getLastColumn() ? sheet.getRange(1,1,1,sheet.getLastColumn()).getValues()[0].map(String) : [];
  const missing = headers.filter(header => !existing.includes(header));
  if (!existing.length) {
    sheet.getRange(1,1,1,headers.length).setValues([headers]);
  } else if (missing.length) {
    sheet.getRange(1,existing.length + 1,1,missing.length).setValues([missing]);
  }
  PDS_formatHeader_(sheet);
}

function PDS_formatHeader_(sheet) {
  if (!sheet.getLastColumn()) return;
  sheet.setFrozenRows(1);
  sheet.getRange(1,1,1,sheet.getLastColumn()).setFontWeight('bold').setBackground('#2f4356').setFontColor('#ffffff');
}

function PDS_seedSettings_() {
  const sheet = PDS_getSheet_(PDS.SHEETS.SETTINGS);
  const existing = PDS_getRecords_(PDS.SHEETS.SETTINGS);
  const existingKeys = new Set(existing.map(r => String(r.SettingKey || '')));
  const seeds = [
    ['BusinessName','Petite Design Studio',''], ['ProjectPrefix','PDS',''],
    ['DefaultTargetMargin','0.30',''], ['Currency','USD','']
  ];
  seeds.forEach(row => { if (!existingKeys.has(row[0])) sheet.appendRow(row); });
}
