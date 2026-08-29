function PDS_createClient(clientData) {
  clientData = clientData || {};
  const firstName = String(clientData.firstName || '').trim();
  const lastName = String(clientData.lastName || '').trim();
  if (!firstName || !lastName) throw new Error('First and last name are required.');
  const email = String(clientData.email || '').trim().toLowerCase();
  if (email) {
    const duplicate = PDS_getRecords_(PDS.SHEETS.CLIENTS).find(r => String(r.Email || '').trim().toLowerCase() === email && r.Active !== false);
    if (duplicate) throw new Error('A client with that email already exists.');
  }
  const now = new Date();
  const record = {
    ClientID: PDS_generateId_('CLI'), FirstName: firstName, LastName: lastName,
    PreferredName: String(clientData.preferredName || '').trim(), Email: email,
    Phone: String(clientData.phone || '').trim(), PropertyAddress: String(clientData.propertyAddress || '').trim(),
    BillingAddress: String(clientData.billingAddress || '').trim(), PreferredCommunicationMethod: String(clientData.preferredCommunicationMethod || '').trim(),
    ReferralSource: String(clientData.referralSource || '').trim(), Notes: String(clientData.notes || '').trim(),
    CreatedDate: now, LastUpdatedDate: now, Active: true
  };
  PDS_appendRecord_(PDS.SHEETS.CLIENTS, record);
  PDS_logActivity_('', 'Client', record.ClientID, 'Created', 'Client added: ' + PDS_getClientDisplayName_(record));
  return PDS_serializeClient_(record);
}

function PDS_getClients() {
  return PDS_getRecords_(PDS.SHEETS.CLIENTS).filter(r => r.Active !== false).map(PDS_serializeClient_);
}

function PDS_getClientDirectoryData() {
  const clients = PDS_getRecords_(PDS.SHEETS.CLIENTS).filter(r => r.Active !== false);
  const projects = PDS_getRecords_(PDS.SHEETS.PROJECTS);
  return clients.map(client => {
    const clientProjects = projects.filter(project => String(project.ClientID) === String(client.ClientID) && project.Archived !== true);
    return {
      clientId: client.ClientID,
      name: PDS_getClientDisplayName_(client),
      email: client.Email || '', phone: client.Phone || '', propertyAddress: client.PropertyAddress || '',
      totalProjects: clientProjects.length,
      activeProjects: clientProjects.filter(project => !['Complete','Archived'].includes(String(project.ProjectStatus || ''))).length
    };
  }).sort((a,b) => a.name.localeCompare(b.name));
}

function PDS_getClient(clientId) {
  const record = PDS_findRecord_(PDS.SHEETS.CLIENTS, 'ClientID', clientId);
  return record ? PDS_serializeClient_(record) : null;
}

function PDS_getClientDisplayName_(client) {
  return String(client.PreferredName || '').trim() || [client.FirstName, client.LastName].filter(Boolean).join(' ').trim();
}

function PDS_serializeClient_(client) {
  return {
    ClientID: client.ClientID || '', FirstName: client.FirstName || '', LastName: client.LastName || '',
    PreferredName: client.PreferredName || '', DisplayName: PDS_getClientDisplayName_(client),
    Email: client.Email || '', Phone: client.Phone || '', PropertyAddress: client.PropertyAddress || '',
    BillingAddress: client.BillingAddress || '', PreferredCommunicationMethod: client.PreferredCommunicationMethod || '',
    ReferralSource: client.ReferralSource || '', Notes: client.Notes || '', Active: client.Active !== false
  };
}
