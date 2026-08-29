const PDS = Object.freeze({
  APP_NAME: 'Petite Design Studio',
  APP_VERSION: '0.3.0',
  PROPERTY_KEYS: {
    SPREADSHEET_ID: 'PDS_SPREADSHEET_ID',
    PROJECT_ROOT_FOLDER_ID: 'PDS_PROJECT_ROOT_FOLDER_ID'
  },
  SHEETS: {
    SETTINGS: 'Settings', USERS: 'Users', CLIENTS: 'Clients', PROJECTS: 'Projects',
    ROOMS: 'Rooms', DESIGN_RECORDS: 'DesignRecords', MEASUREMENTS: 'Measurements',
    ESTIMATES: 'Estimates', ESTIMATE_ITEMS: 'EstimateItems', VENDORS: 'Vendors',
    EXPENSES: 'Expenses', INVOICES: 'Invoices', PAYMENTS: 'Payments',
    CHANGE_ORDERS: 'ChangeOrders', FILES: 'Files', COMMUNICATIONS: 'Communications',
    ACTIVITY_LOG: 'ActivityLog'
  },
  PROJECT_STATUSES: [
    'New Inquiry','Consultation','Design','Estimating','Proposal Sent','Client Review',
    'Approved','In Progress','Awaiting Final Payment','Complete','Archived'
  ]
});

function PDS_getConfig_() {
  const props = PropertiesService.getScriptProperties();
  return {
    spreadsheetId: props.getProperty(PDS.PROPERTY_KEYS.SPREADSHEET_ID) || '',
    projectRootFolderId: props.getProperty(PDS.PROPERTY_KEYS.PROJECT_ROOT_FOLDER_ID) || ''
  };
}

function PDS_isSpreadsheetConfigured_() {
  return Boolean(PDS_getConfig_().spreadsheetId);
}

function PDS_isProjectFolderConfigured_() {
  return Boolean(PDS_getConfig_().projectRootFolderId);
}

function PDS_getPublicConfig_() {
  return { appName: PDS.APP_NAME, appVersion: PDS.APP_VERSION };
}
