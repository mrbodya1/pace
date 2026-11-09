// Email/password alpha accounts. Workout data stays on the device.
migrate(function (app) {
    var owner = "@request.auth.collectionId = 'paceaccounts001' && id = @request.auth.id";
    var protectedFields = "@request.body.verified:isset = false && @request.body.emailVisibility:isset = false";
    var collection = new Collection({
        id: "paceaccounts001",
        name: "pace_users",
        type: "auth",
        listRule: owner,
        viewRule: owner,
        createRule: protectedFields,
        updateRule: owner + " && " + protectedFields,
        deleteRule: null,
        manageRule: null,
        authRule: "",
        passwordAuth: { enabled: true, identityFields: ["email"] },
        oauth2: { enabled: false, providers: [] },
        otp: { enabled: false },
        authAlert: { enabled: false },
        fields: [{ name: "name", type: "text", max: 40 }]
    });
    collection.fields.getByName("password").min = 12;
    app.save(collection);

    // Keep PocketBase's built-in rules instead of replacing operator settings.
    var settings = app.settings();
    settings.rateLimits.enabled = true;
    app.save(settings);
});
