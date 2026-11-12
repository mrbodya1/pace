function savedRules(event) {
  try {const value=JSON.parse(event.getString('scoring'));return value && value.version===1?value:null;}catch(_){return null;}
}
function existing(app,event,user) {
  const rows=app.findRecordsByFilter('pace_competition_scores','event = {:event} && user = {:user}','',1,0,{event,user});
  return rows.length?rows[0]:null;
}
function remove(app,event,user) {const row=existing(app,event,user);if(row)app.delete(row);}
function sync(app,user,snapshot) {
  for(const entry of app.findRecordsByFilter('pace_community_members','user = {:user} && kind = "event"','',0,0,{user})) {
    let event;try{event=app.findRecordById('pace_events',entry.getString('target'));}catch(_){continue;}
    const rule=savedRules(event);if(!rule || event.getString('kind')!=='competition')continue;
    if(event.getString('audience')==='club' && app.countRecords('pace_community_members',$dbx.hashExp({user,kind:'club',target:event.getString('club')}))===0){remove(app,event.id,user);continue;}
    const result=require(`${__hooks}/lib/competition_engine.js`).calculate(rule,{sport:event.getString('sport'),startsAt:event.getString('startsAt'),endsAt:event.getString('endsAt')},entry.getString('joinedAt'),snapshot && Array.isArray(snapshot.workouts)?snapshot.workouts:[],Date.now());
    const row=existing(app,event.id,user)||new Record(app.findCollectionByNameOrId('pace_competition_scores'));
    row.set('event',event.id);row.set('user',user);row.set('score',result.score);row.set('workouts',result.workouts);row.set('excluded',result.excluded);app.save(row);
  }
}
function snapshot(app,user) {
  if(!require(`${__hooks}/lib/workouts_v2.js`).legacy()){
    return {workouts:app.findRecordsByFilter('pace_v2_workouts','owner={:owner}','revision',0,0,{owner:user}).map(r=>JSON.parse(r.getString('summary')))};
  }
  const rows=app.findRecordsByFilter('pace_progress','owner = {:user}','',1,0,{user});
  return rows.length?JSON.parse(rows[0].getString('snapshot')):null;
}
function results(e,id,page) {
  if(typeof id!=='string' || !/^[a-z0-9]{15}$/.test(id) || !Number.isSafeInteger(page) || page<0 || page>10000)throw new BadRequestError('Проверь соревнование и страницу');
  let event;try{event=e.app.findRecordById('pace_events',id);}catch(_){throw new NotFoundError('Соревнование не найдено');}
  if(event.getString('kind')!=='competition')throw new BadRequestError('У этого события нет соревновательного зачёта');
  if(event.getString('audience')==='club' && e.app.countRecords('pace_community_members',$dbx.hashExp({user:e.auth.id,kind:'club',target:event.getString('club')}))===0)throw new ForbiddenError('Результаты доступны участникам клуба');
  const rule=savedRules(event);if(!rule)return {available:false};
  e.app.runInTransaction(app=>sync(app,e.auth.id,snapshot(app,e.auth.id)));
  const rows=e.app.findRecordsByFilter('pace_competition_scores','event = {:id} && workouts > 0','-score,id',26,page*25,{id});
  const mine=existing(e.app,id,e.auth.id);
  const rank=score=>1+e.app.countRecords('pace_competition_scores',$dbx.exp('event = {:id} AND workouts > 0 AND score > {:score}',{id,score}));
  return {available:true,rule,page,hasMore:rows.length>25,participants:e.app.countRecords('pace_community_members',$dbx.hashExp({kind:'event',target:id})),ranked:e.app.countRecords('pace_competition_scores',$dbx.exp('event = {:id} AND workouts > 0',{id})),rows:rows.slice(0,25).map(row=>({entryId:row.id,name:e.app.findRecordById('pace_users',row.getString('user')).getString('name')||'Участник',me:row.getString('user')===e.auth.id,score:row.getInt('score'),workouts:row.getInt('workouts'),rank:rank(row.getInt('score'))})),mine:mine?{score:mine.getInt('score'),workouts:mine.getInt('workouts'),rank:mine.getInt('workouts')>0?rank(mine.getInt('score')):null,excluded:JSON.parse(mine.getString('excluded'))}:null};
}
module.exports={savedRules,sync,remove,results,snapshot};
