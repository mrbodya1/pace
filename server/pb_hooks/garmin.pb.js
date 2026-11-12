routerAdd("GET", "/api/pace/garmin", (e) => {
  return require(`${__hooks}/lib/garmin.js`).read(e);
}, $apis.requireAuth("pace_users"));
routerAdd("POST", "/api/pace/garmin/refresh", (e) => {
  return require(`${__hooks}/lib/garmin.js`).refresh(e);
}, $apis.requireAuth("pace_users"), $apis.bodyLimit(1024));
