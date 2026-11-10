function find(app, owner) {
  const records = app.findRecordsByFilter("pace_progress", "owner = {:owner}", "", 1, 0, {owner: owner});
  return records.length ? records[0] : null;
}
function unpack(record) {
  return record ? {revision: record.getInt("revision"), data: JSON.parse(record.getString("snapshot"))} : {revision: 0, data: null};
}
function validate(data) {
  if (!data || data.version !== 1 || !Number.isSafeInteger(data.xp) || data.xp < 0 || !Array.isArray(data.workouts) || !data.achievements || !data.records) {
    throw new BadRequestError("Invalid progress snapshot");
  }
  const ids = new Set();
  for (const w of data.workouts) {
    if (!w || typeof w.sessionId !== "string" || !w.sessionId || w.sessionId.length > 128 || ids.has(w.sessionId) || !Number.isSafeInteger(w.xp) || w.xp < 0 || !Number.isFinite(w.distance) || w.distance < 0 || !Number.isSafeInteger(w.durationSeconds) || w.durationSeconds < 0) {
      throw new BadRequestError("Invalid or duplicate workout");
    }
    ids.add(w.sessionId);
  }
  return ids;
}
module.exports = {
  read: (e) => e.json(200, unpack(find(e.app, e.auth.id))),
  write: (e) => {
    const body = e.requestInfo().body;
    if (!Number.isSafeInteger(body.revision) || body.revision < 0) throw new BadRequestError("Invalid revision");
    const ids = validate(body.data);
    let response;
    e.app.runInTransaction((app) => {
      let record = find(app, e.auth.id);
      const current = unpack(record);
      if (current.revision !== body.revision) throw new ApiError(409, "Progress changed; merge and retry");
      // This phase has no delete/edit API: a stale or buggy client cannot drop history.
      if (current.data) {
        for (const w of current.data.workouts) {
          if (!ids.has(w.sessionId)) throw new BadRequestError("Existing workouts must be retained");
        }
      }
      if (!record) {
        record = new Record(app.findCollectionByNameOrId("pace_progress"));
        record.set("owner", e.auth.id);
      }
      record.set("snapshot", body.data);
      record.set("revision", current.revision + 1);
      app.save(record);
      response = {revision: current.revision + 1, data: body.data};
    });
    return e.json(200, response);
  }
};
