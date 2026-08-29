function PDS_generateId_(prefix) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const props = PropertiesService.getScriptProperties();
    const key = 'PDS_ID_COUNTER_' + prefix;
    const next = Number(props.getProperty(key) || 0) + 1;
    props.setProperty(key, String(next));
    return prefix + '-' + String(next).padStart(6,'0');
  } finally {
    lock.releaseLock();
  }
}

function PDS_generateProjectId_() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const year = new Date().getFullYear();
    const props = PropertiesService.getScriptProperties();
    const key = 'PDS_PROJECT_COUNTER_' + year;
    const next = Number(props.getProperty(key) || 0) + 1;
    props.setProperty(key, String(next));
    return 'PDS-' + year + '-' + String(next).padStart(4,'0');
  } finally {
    lock.releaseLock();
  }
}
