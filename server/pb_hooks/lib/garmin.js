// Local Personal API inbox, readable only by the explicitly bound PACE owner.
function rootPath() {
  return $os.getenv("PACE_GARMIN_RUNTIME") || $filepath.clean(`${__hooks}/../../../Runtime/Garmin`);
}
function readConfig(root) {
  try { return JSON.parse(toString($os.readFile(`${root}/import-config.json`))); }
  catch (_) { return null; }
}
module.exports = {
  status: (e) => {
    const config=readConfig(rootPath());
    if(!config || config.version!==1 || config.ownerId!==e.auth.id)return e.json(200,{available:false,refresh:{phase:'idle'}});
    return e.json(200,{available:true,refresh:refreshState(rootPath())});
  },
  refresh: (e) => {
    const config = readConfig(rootPath());
    if (!config || config.version !== 1 || config.ownerId !== e.auth.id) throw new ForbiddenError("Garmin is not linked to this account");
    const body = e.requestInfo().body;
    if (body.force !== undefined && typeof body.force !== "boolean") throw new BadRequestError("Invalid refresh request");
    const launcher = $filepath.clean(`${__hooks}/../garmin/request-personal-refresh.ps1`);
    const args = ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", launcher];
    if (body.force === true) args.push("-ForceRefresh");
    let result;
    try { result = JSON.parse(toString($os.cmd("powershell.exe", ...args).output())); }
    catch (_) { throw new ApiError(503, "Garmin refresh is unavailable"); }
    return e.json(202, {phase: ['ready','error'].includes(result.phase) ? result.phase : 'running'});
  },
  read: (e) => {
    const root = rootPath();
    let config;
    try { config = JSON.parse(toString($os.readFile(`${root}/import-config.json`))); }
    catch (_) { return e.json(200, {available: false, activities: []}); }
    if (config.version !== 1 || config.ownerId !== e.auth.id) {
      return e.json(200, {available: false, activities: []});
    }
    let inbox;
    try { inbox = JSON.parse(toString($os.readFile(`${root}/inbox.json`))); }
    catch (_) { throw new ApiError(503, "Garmin inbox is not ready"); }
    const since = Date.parse(config.sinceUtc);
    if (!Number.isFinite(since) || inbox.version !== 1 || inbox.ownerId !== e.auth.id ||
        inbox.sinceUtc !== config.sinceUtc || !Array.isArray(inbox.activities) || inbox.activities.length > 200) {
      throw new ApiError(503, "Invalid Garmin inbox");
    }
    const ids = new Set();
    for (const a of inbox.activities) {
      if (!a || a.source !== "garmin-personal" || !/^[0-9]{1,20}$/.test(a.externalId) ||
          ids.has(a.externalId) || !Number.isFinite(Date.parse(a.startedAt)) || Date.parse(a.startedAt) < since) {
        throw new ApiError(503, "Invalid Garmin activity");
      }
      ids.add(a.externalId);
    }
    return e.json(200, {available: true, sinceUtc: config.sinceUtc, refresh:refreshState(root), activities: inbox.activities});
  }
};
function refreshState(root) {
    let refresh = {phase: "idle"};
    try {
      const status = JSON.parse(toString($os.readFile(`${root}/refresh-state.json`)));
      if (["running", "starting"].includes(status.phase)) {
        refresh = {phase: Date.now() - Date.parse(status.startedAt) < 300000 ? "running" : "error"};
      } else if (["ready", "error"].includes(status.phase)) refresh = {phase: status.phase};
    } catch (_) { }
    return refresh;
}
