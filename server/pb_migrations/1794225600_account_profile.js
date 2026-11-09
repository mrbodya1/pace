// Account-owned profile; workouts and XP remain on the device.
migrate((app) => {
    const collection = app.findCollectionByNameOrId("pace_users");
    collection.fields.add(new JSONField({name: "profile", maxSize: 16384}));
    app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("pace_users");
    collection.fields.removeByName("profile");
    app.save(collection);
});
