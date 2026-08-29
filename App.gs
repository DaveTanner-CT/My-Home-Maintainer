function doGet() {
  return HtmlService.createTemplateFromFile('Index')
    .evaluate()
    .setTitle('Petite Design Studio')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

function PDS_getAppBootstrapData() {
  if (!PDS_isSpreadsheetConfigured_()) {
    return { configured: false, publicConfig: PDS_getPublicConfig_(), clients: [], projects: [], dashboard: {} };
  }
  const clients = PDS_getClientDirectoryData();
  const projects = PDS_getProjectListData();
  const activeProjects = projects.filter(p => !['Complete','Archived'].includes(String(p.status || ''))).length;
  return {
    configured: true,
    publicConfig: PDS_getPublicConfig_(),
    clients: clients,
    projects: projects,
    dashboard: {
      totalClients: clients.length,
      totalProjects: projects.length,
      activeProjects: activeProjects,
      recentProjects: projects.slice(0,6)
    }
  };
}

function PDS_safeDateForClient_(value) {
  if (!value) return '';
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value)) {
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return String(value);
}

function PDS_safeDateTimeForClient_(value) {
  if (!value) return '';
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value)) {
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm');
  }
  return String(value);
}
