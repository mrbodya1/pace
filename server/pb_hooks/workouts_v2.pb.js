routerAdd('GET','/api/pace/v2/state',e=>e.json(200,require(`${__hooks}/lib/workouts_v2.js`).state(e.app,e.auth.id)),$apis.requireAuth('pace_users'));
routerAdd('POST','/api/pace/v2/workouts',e=>require(`${__hooks}/lib/workouts_v2.js`).action(e),$apis.requireAuth('pace_users'),$apis.bodyLimit(262144));
