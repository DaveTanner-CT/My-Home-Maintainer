function PDS_createRoom(roomData) {
  roomData = roomData || {};
  const projectId = String(roomData.projectId || '').trim();
  const roomName = String(roomData.roomName || '').trim();
  if (!projectId || !roomName) throw new Error('Project and room name are required.');
  if (!PDS_findRecord_(PDS.SHEETS.PROJECTS, 'ProjectID', projectId)) throw new Error('Project not found.');
  const roomCount = PDS_getRecords_(PDS.SHEETS.ROOMS).filter(room => String(room.ProjectID) === projectId).length;
  const now = new Date();
  const record = {
    RoomID: PDS_generateId_('ROOM'), ProjectID: projectId, RoomName: roomName,
    RoomType: String(roomData.roomType || '').trim(), SortOrder: roomCount + 1,
    Notes: String(roomData.notes || '').trim(), CreatedDate: now, LastUpdatedDate: now
  };
  PDS_appendRecord_(PDS.SHEETS.ROOMS, record);
  PDS_logActivity_(projectId, 'Room', record.RoomID, 'Created', 'Room added: ' + roomName);
  return PDS_serializeRoom_(record);
}

function PDS_serializeRoom_(room) {
  return { roomId: room.RoomID || '', projectId: room.ProjectID || '', roomName: room.RoomName || '', roomType: room.RoomType || '', sortOrder: Number(room.SortOrder || 0), notes: room.Notes || '' };
}
