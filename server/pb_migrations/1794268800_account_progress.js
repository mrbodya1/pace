// Account-owned progress. All writes go through the revision-checked endpoint.
migrate((app) => {
  app.save(new Collection({
    id: "paceprogress001", name: "pace_progress", type: "base",
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
    fields: [
      {name: "owner", type: "relation", collectionId: "paceaccounts001", required: true, maxSelect: 1, cascadeDelete: true},
      {name: "revision", type: "number", required: true, onlyInt: true, min: 1},
      {name: "snapshot", type: "json", required: true, maxSize: 33554432}
    ],
    indexes: ["CREATE UNIQUE INDEX idx_pace_progress_owner ON pace_progress (owner)"]
  }));
}, (app) => { app.delete(app.findCollectionByNameOrId("pace_progress")); });
