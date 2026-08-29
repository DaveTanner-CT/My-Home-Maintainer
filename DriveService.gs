function PDS_getProjectRootFolder_() {
  const id = PDS_getConfig_().projectRootFolderId;
  if (!id) throw new Error('The project root folder is not configured.');
  return DriveApp.getFolderById(id);
}

function PDS_createProjectFolder_(project) {
  const root = PDS_getProjectRootFolder_();
  const name = PDS_safeFolderName_((project.ProjectID || '') + ' - ' + (project.ProjectName || 'Project'));
  const projectFolder = root.createFolder(name);
  ['01 Intake','02 Site Photos','03 Design','04 Proposals','05 Contracts','06 Receipts','07 Final']
    .forEach(child => projectFolder.createFolder(child));
  return { projectFolderId: projectFolder.getId(), folder: projectFolder };
}

function PDS_safeFolderName_(value) {
  return String(value || '')
    .replace(/[\\/:*?"<>|#%{}~]/g,'-')
    .replace(/\s+/g,' ')
    .trim()
    .slice(0,160) || 'Untitled';
}
