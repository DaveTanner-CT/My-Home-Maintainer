function PDS_createProject(projectData) {
  projectData = projectData || {};
  const clientId = String(projectData.clientId || '').trim();
  const projectName = String(projectData.projectName || '').trim();
  if (!clientId) throw new Error('Select a client.');
  if (!projectName) throw new Error('Project name is required.');
  const client = PDS_findRecord_(PDS.SHEETS.CLIENTS, 'ClientID', clientId);
  if (!client) throw new Error('The selected client could not be found.');
  const now = new Date();
  const projectId = PDS_generateProjectId_();
  const record = {
    ProjectID: projectId, ClientID: clientId, ProjectName: projectName,
    PropertyAddress: String(projectData.propertyAddress || client.PropertyAddress || '').trim(),
    ScopeSummary: String(projectData.scopeSummary || '').trim(), ProjectStatus: 'New Inquiry',
    InquiryDate: now, ConsultationDate: '', TargetStartDate: PDS_parseDateInput_(projectData.targetStartDate),
    TargetCompletionDate: PDS_parseDateInput_(projectData.targetCompletionDate), ActualCompletionDate: '', LeadDesigner: '',
    DriveFolderID: '', InternalNotes: '', ClientFacingNotes: '', CreatedDate: now, LastUpdatedDate: now, Archived: false
  };
  if (PDS_isProjectFolderConfigured_()) {
    const folderInfo = PDS_createProjectFolder_({
      ProjectID: projectId,
      ProjectName: PDS_getClientDisplayName_(client) + ' - ' + projectName
    });
    record.DriveFolderID = folderInfo.projectFolderId;
  }
  PDS_appendRecord_(PDS.SHEETS.PROJECTS, record);
  PDS_logActivity_(projectId, 'Project', projectId, 'Created', 'Project created: ' + projectName);
  return PDS_getProjectDetail(projectId);
}

function PDS_getProjects() { return PDS_getProjectListData(); }

function PDS_getProjectListData() {
  const clients = PDS_getRecords_(PDS.SHEETS.CLIENTS);
  const clientMap = {};
  clients.forEach(client => clientMap[String(client.ClientID)] = client);
  return PDS_getRecords_(PDS.SHEETS.PROJECTS)
    .filter(project => project.Archived !== true)
    .map(project => ({
      projectId: project.ProjectID || '', projectName: project.ProjectName || '', clientId: project.ClientID || '',
      clientName: clientMap[String(project.ClientID)] ? PDS_getClientDisplayName_(clientMap[String(project.ClientID)]) : '',
      propertyAddress: project.PropertyAddress || '', scopeSummary: project.ScopeSummary || '',
      status: project.ProjectStatus || '', targetStartDate: PDS_safeDateForClient_(project.TargetStartDate),
      targetCompletionDate: PDS_safeDateForClient_(project.TargetCompletionDate), driveFolderId: project.DriveFolderID || ''
    }))
    .sort((a,b) => String(b.projectId).localeCompare(String(a.projectId)));
}

function PDS_getProjectDetail(projectId) {
  const project = PDS_findRecord_(PDS.SHEETS.PROJECTS, 'ProjectID', projectId);
  if (!project) throw new Error('Project not found.');
  const client = PDS_findRecord_(PDS.SHEETS.CLIENTS, 'ClientID', project.ClientID);
  const rooms = PDS_getRecords_(PDS.SHEETS.ROOMS).filter(room => String(room.ProjectID) === String(projectId)).sort((a,b) => Number(a.SortOrder||0)-Number(b.SortOrder||0)).map(PDS_serializeRoom_);
  const activities = PDS_getRecords_(PDS.SHEETS.ACTIVITY_LOG).filter(item => String(item.ProjectID) === String(projectId)).reverse().slice(0,10).map(item => ({
    activityId: item.ActivityID || '', timestamp: PDS_safeDateTimeForClient_(item.Timestamp), description: item.Description || '', action: item.Action || ''
  }));
  return {
    project: {
      projectId: project.ProjectID || '', clientId: project.ClientID || '', projectName: project.ProjectName || '',
      propertyAddress: project.PropertyAddress || '', scopeSummary: project.ScopeSummary || '', status: project.ProjectStatus || '',
      targetStartDate: PDS_safeDateForClient_(project.TargetStartDate), targetCompletionDate: PDS_safeDateForClient_(project.TargetCompletionDate),
      driveFolderId: project.DriveFolderID || ''
    },
    client: client ? PDS_serializeClient_(client) : {}, rooms: rooms, activities: activities
  };
}

function PDS_parseDateInput_(value) {
  if (!value) return '';
  if (Object.prototype.toString.call(value) === '[object Date]') return value;
  const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return value;
  return new Date(Number(match[1]), Number(match[2])-1, Number(match[3]));
}
