routerAdd('GET', '/api/pace/community', (e) => require(`${__hooks}/lib/community.js`).read(e), $apis.requireAuth('pace_users'));
routerAdd('POST', '/api/pace/community/action', (e) => require(`${__hooks}/lib/community.js`).action(e), $apis.requireAuth('pace_users'), $apis.bodyLimit(8192));
