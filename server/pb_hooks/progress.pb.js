routerAdd("GET", "/api/pace/progress", (e) => {
  return require(`${__hooks}/lib/progress.js`).read(e);
}, $apis.requireAuth("pace_users"));
routerAdd("PUT", "/api/pace/progress", (e) => {
  return require(`${__hooks}/lib/progress.js`).write(e);
}, $apis.requireAuth("pace_users"), $apis.bodyLimit(33554432));
