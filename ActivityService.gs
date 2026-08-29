function PDS_logActivity_(projectId, entityType, entityId, action, description) {
  if (!PDS_isSpreadsheetConfigured_()) return;
  PDS_appendRecord_(PDS.SHEETS.ACTIVITY_LOG, {
    ActivityID: PDS_generateId_('ACT'),
    Timestamp: new Date(),
    UserEmail: Session.getActiveUser().getEmail() || '',
    ProjectID: projectId || '',
    EntityType: entityType || '',
    EntityID: entityId || '',
    Action: action || '',
    Description: description || ''
  });
}
