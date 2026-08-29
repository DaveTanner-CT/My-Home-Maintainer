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
    Notes: String(roomData.notes || '').trim(),
    LengthFeet: '', LengthInches: '', WidthFeet: '', WidthInches: '',
    CeilingHeightFeet: '', CeilingHeightInches: '', DimensionUnit: 'feet',
    CreatedDate: now, LastUpdatedDate: now
  };
  PDS_appendRecord_(PDS.SHEETS.ROOMS, record);
  PDS_logActivity_(projectId, 'Room', record.RoomID, 'Created', 'Room added: ' + roomName);
  return PDS_serializeRoom_(record);
}

function PDS_getRoomDetail(roomId) {
  const room = PDS_findRecord_(PDS.SHEETS.ROOMS, 'RoomID', roomId);
  if (!room) throw new Error('Room not found.');

  const photos = PDS_getRecords_(PDS.SHEETS.DESIGN_RECORDS)
    .filter(record =>
      String(record.RoomID || '') === String(roomId) &&
      String(record.RecordType || '') === 'Site Photo'
    )
    .reverse()
    .map(PDS_serializeDesignRecord_);

  return {
    room: PDS_serializeRoom_(room),
    photos: photos
  };
}

function PDS_updateRoomDimensions(data) {
  data = data || {};
  const roomId = String(data.roomId || '').trim();
  if (!roomId) throw new Error('Room is required.');

  PDS_ensureRoomDimensionColumns_();

  const existing = PDS_findRecord_(PDS.SHEETS.ROOMS, 'RoomID', roomId);
  if (!existing) throw new Error('Room not found.');

  const cleanWhole = value => {
    if (value === '' || value === null || typeof value === 'undefined') return '';
    const n = Number(value);
    if (!Number.isFinite(n) || n < 0) throw new Error('Room dimensions must be positive numbers.');
    return Math.floor(n);
  };

  const cleanInches = value => {
    if (value === '' || value === null || typeof value === 'undefined') return '';
    const n = Number(value);
    if (!Number.isFinite(n) || n < 0 || n >= 12) throw new Error('Inches must be between 0 and 11.99.');
    return Math.round(n * 100) / 100;
  };

  const updates = {
    LengthFeet: cleanWhole(data.lengthFeet),
    LengthInches: cleanInches(data.lengthInches),
    WidthFeet: cleanWhole(data.widthFeet),
    WidthInches: cleanInches(data.widthInches),
    CeilingHeightFeet: cleanWhole(data.ceilingHeightFeet),
    CeilingHeightInches: cleanInches(data.ceilingHeightInches),
    DimensionUnit: String(data.dimensionUnit || 'feet') === 'meters' ? 'meters' : 'feet',
    LastUpdatedDate: new Date()
  };

  const updated = PDS_updateRecord_(PDS.SHEETS.ROOMS, 'RoomID', roomId, updates);
  PDS_logActivity_(existing.ProjectID, 'Room', roomId, 'Updated', 'Room dimensions updated: ' + (existing.RoomName || roomId));
  return PDS_serializeRoom_(updated);
}

function PDS_ensureRoomDimensionColumns_() {
  const sheet = PDS_getSheet_(PDS.SHEETS.ROOMS);
  const existing = PDS_getHeaders_(PDS.SHEETS.ROOMS);
  const required = ['LengthFeet','LengthInches','WidthFeet','WidthInches','CeilingHeightFeet','CeilingHeightInches','DimensionUnit'];
  const missing = required.filter(header => !existing.includes(header));
  if (missing.length) {
    sheet.getRange(1, existing.length + 1, 1, missing.length).setValues([missing]);
    PDS_formatHeader_(sheet);
  }
}

function PDS_serializeRoom_(room) {
  const num = value => value === '' || value === null || typeof value === 'undefined' ? '' : Number(value);
  return {
    roomId: room.RoomID || '',
    projectId: room.ProjectID || '',
    roomName: room.RoomName || '',
    roomType: room.RoomType || '',
    sortOrder: Number(room.SortOrder || 0),
    notes: room.Notes || '',
    lengthFeet: num(room.LengthFeet),
    lengthInches: num(room.LengthInches),
    widthFeet: num(room.WidthFeet),
    widthInches: num(room.WidthInches),
    ceilingHeightFeet: num(room.CeilingHeightFeet),
    ceilingHeightInches: num(room.CeilingHeightInches),
    dimensionUnit: String(room.DimensionUnit || 'feet') === 'meters' ? 'meters' : 'feet'
  };
}
