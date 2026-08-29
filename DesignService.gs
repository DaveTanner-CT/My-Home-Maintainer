function PDS_getDesignWorkspace(projectId) {
  const project = PDS_findRecord_(PDS.SHEETS.PROJECTS, 'ProjectID', projectId);
  if (!project) throw new Error('Project not found.');
  const rooms = PDS_getRecords_(PDS.SHEETS.ROOMS)
    .filter(room => String(room.ProjectID) === String(projectId))
    .sort((a,b) => Number(a.SortOrder||0)-Number(b.SortOrder||0))
    .map(PDS_serializeRoom_);
  const records = PDS_getRecords_(PDS.SHEETS.DESIGN_RECORDS)
    .filter(record => String(record.ProjectID) === String(projectId))
    .reverse()
    .map(PDS_serializeDesignRecord_);
  return { projectId: projectId, rooms: rooms, records: records };
}

function PDS_createDesignNote(data) {
  data = data || {};
  const projectId = String(data.projectId || '').trim();
  const title = String(data.title || '').trim();
  const description = String(data.description || '').trim();
  if (!projectId || !title || !description) throw new Error('Project, title, and note are required.');
  const now = new Date();
  const record = {
    DesignRecordID: PDS_generateId_('DES'), ProjectID: projectId, RoomID: String(data.roomId || '').trim(),
    RecordType: 'Design Note', Title: title, Description: description, DriveFileID: '', OriginalDesignRecordID: '',
    ParentDesignRecordID: '', VersionNumber: 1, CreatedDate: now, CreatedBy: Session.getActiveUser().getEmail() || '',
    LastModifiedDate: now, ClientVisible: Boolean(data.clientVisible), Notes: ''
  };
  PDS_appendRecord_(PDS.SHEETS.DESIGN_RECORDS, record);
  PDS_logActivity_(projectId, 'DesignRecord', record.DesignRecordID, 'Created', 'Design note added: ' + title);
  return PDS_serializeDesignRecord_(record);
}

function PDS_uploadDesignPhoto(formObject) {
  formObject = formObject || {};
  const projectId = String(formObject.projectId || '').trim();
  const blob = formObject.designPhoto;
  if (!projectId) throw new Error('Project is required.');
  if (!blob || typeof blob.getBytes !== 'function') throw new Error('Choose a photo to upload.');
  const project = PDS_findRecord_(PDS.SHEETS.PROJECTS, 'ProjectID', projectId);
  if (!project) throw new Error('Project not found.');
  const roomId = String(formObject.roomId || '').trim();
  const folder = PDS_getDesignStorageFolder_(project, roomId);
  const title = String(formObject.title || blob.getName() || 'Site Photo').trim();
  const safeName = PDS_safeFolderName_(projectId + ' - ' + title);
  const originalName = String(blob.getName() || 'photo.jpg');
  const dot = originalName.lastIndexOf('.');
  const extension = dot >= 0 ? originalName.slice(dot) : '.jpg';
  blob.setName(safeName + extension);
  const file = folder.createFile(blob);
  const now = new Date();
  const record = {
    DesignRecordID: PDS_generateId_('DES'), ProjectID: projectId, RoomID: roomId, RecordType: 'Site Photo',
    Title: title, Description: String(formObject.description || '').trim(), DriveFileID: file.getId(),
    OriginalDesignRecordID: '', ParentDesignRecordID: '', VersionNumber: 1, CreatedDate: now,
    CreatedBy: Session.getActiveUser().getEmail() || '', LastModifiedDate: now,
    ClientVisible: String(formObject.clientVisible || '') === 'on', Notes: ''
  };
  PDS_appendRecord_(PDS.SHEETS.DESIGN_RECORDS, record);
  PDS_logActivity_(projectId, 'DesignRecord', record.DesignRecordID, 'Created', 'Site photo added: ' + title);
  return PDS_serializeDesignRecord_(record);
}

function PDS_saveDesignSketch(data) {
  data = data || {};
  const projectId = String(data.projectId || '').trim();
  if (!projectId) throw new Error('A Project ID is required.');
  const project = PDS_findRecord_(PDS.SHEETS.PROJECTS, 'ProjectID', projectId);
  if (!project) throw new Error('The project could not be found.');
  const imageData = String(data.imageData || '');
  if (!imageData.startsWith('data:image/png;base64,')) throw new Error('The sketch image could not be processed.');
  const roomId = String(data.roomId || '').trim();
  const title = String(data.title || '').trim() || 'Design Sketch';
  const bytes = Utilities.base64Decode(imageData.replace(/^data:image\/png;base64,/,''));
  const fileName = PDS_safeFolderName_(projectId + ' - ' + title) + '.png';
  const folder = PDS_getDesignStorageFolder_(project, roomId);
  const file = folder.createFile(Utilities.newBlob(bytes,'image/png',fileName));
  const now = new Date();
  const record = {
    DesignRecordID: PDS_generateId_('DES'), ProjectID: projectId, RoomID: roomId, RecordType: 'Sketch',
    Title: title, Description: String(data.description || '').trim(), DriveFileID: file.getId(),
    OriginalDesignRecordID: '', ParentDesignRecordID: '', VersionNumber: 1, CreatedDate: now,
    CreatedBy: Session.getActiveUser().getEmail() || '', LastModifiedDate: now,
    ClientVisible: Boolean(data.clientVisible), Notes: 'Background: ' + String(data.background || 'blank')
  };
  PDS_appendRecord_(PDS.SHEETS.DESIGN_RECORDS, record);
  PDS_logActivity_(projectId, 'DesignRecord', record.DesignRecordID, 'Created', 'Design sketch added: ' + title);
  return PDS_serializeDesignRecord_(record);
}

function PDS_getDesignRecordAsset(designRecordId) {
  const record = PDS_findRecord_(PDS.SHEETS.DESIGN_RECORDS, 'DesignRecordID', designRecordId);
  if (!record) throw new Error('Design record not found.');
  if (!record.DriveFileID) throw new Error('This design record does not have an image file.');
  const blob = DriveApp.getFileById(record.DriveFileID).getBlob();
  const contentType = blob.getContentType() || 'image/png';
  return { record: PDS_serializeDesignRecord_(record), dataUrl: 'data:' + contentType + ';base64,' + Utilities.base64Encode(blob.getBytes()) };
}

function PDS_updateDesignRecordDetails(data) {
  data = data || {};
  const id = String(data.designRecordId || '').trim();
  if (!id) throw new Error('A Design Record ID is required.');
  const existing = PDS_findRecord_(PDS.SHEETS.DESIGN_RECORDS, 'DesignRecordID', id);
  if (!existing) throw new Error('The design record could not be found.');
  PDS_updateRecord_(PDS.SHEETS.DESIGN_RECORDS, 'DesignRecordID', id, {
    RoomID: data.roomId || '', Title: String(data.title || '').trim(), Description: String(data.description || '').trim(),
    ClientVisible: Boolean(data.clientVisible), LastModifiedDate: new Date()
  });
  PDS_logActivity_(existing.ProjectID, 'DesignRecord', existing.DesignRecordID, 'Updated', 'Design record updated: ' + (data.title || existing.Title || 'Design Record'));
  return PDS_serializeDesignRecord_(PDS_findRecord_(PDS.SHEETS.DESIGN_RECORDS, 'DesignRecordID', id));
}

function PDS_getDesignStorageFolder_(project, roomId) {
  let projectFolderId = project.DriveFolderID || '';
  if (!projectFolderId) {
    if (!PDS_isProjectFolderConfigured_()) throw new Error('Project Drive storage is not configured.');
    const client = PDS_findRecord_(PDS.SHEETS.CLIENTS, 'ClientID', project.ClientID);
    const folderInfo = PDS_createProjectFolder_({
      ProjectID: project.ProjectID,
      ProjectName: (client ? PDS_getClientDisplayName_(client) + ' - ' : '') + (project.ProjectName || 'Project')
    });
    projectFolderId = folderInfo.projectFolderId;
    PDS_updateRecord_(PDS.SHEETS.PROJECTS,'ProjectID',project.ProjectID,{DriveFolderID: projectFolderId, LastUpdatedDate: new Date()});
    project.DriveFolderID = projectFolderId;
  }
  const projectFolder = DriveApp.getFolderById(projectFolderId);
  const designFolder = PDS_getOrCreateFolder_(projectFolder, '03 Design');
  if (!roomId) return designFolder;
  const room = PDS_findRecord_(PDS.SHEETS.ROOMS,'RoomID',roomId);
  return room ? PDS_getOrCreateFolder_(designFolder, PDS_safeFolderName_(room.RoomName || roomId)) : designFolder;
}

function PDS_getOrCreateFolder_(parentFolder, folderName) {
  const folders = parentFolder.getFoldersByName(folderName);
  return folders.hasNext() ? folders.next() : parentFolder.createFolder(folderName);
}

function PDS_serializeDesignRecord_(record) {
  const id = record.DriveFileID || '';
  return {
    designRecordId: record.DesignRecordID || '', projectId: record.ProjectID || '', roomId: record.RoomID || '',
    recordType: record.RecordType || '', title: record.Title || '', description: record.Description || '',
    driveFileId: id, versionNumber: Number(record.VersionNumber || 1), createdDate: PDS_safeDateTimeForClient_(record.CreatedDate),
    clientVisible: record.ClientVisible === true || String(record.ClientVisible).toLowerCase() === 'true',
    driveUrl: id ? 'https://drive.google.com/file/d/' + id + '/view' : '',
    thumbnailUrl: id ? 'https://drive.google.com/thumbnail?id=' + id + '&sz=w800' : ''
  };
}
