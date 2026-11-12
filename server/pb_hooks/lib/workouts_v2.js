const kinds=['route','timedRoute','heartRateSamples'];
function empty(){return {version:2,xp:0,achievements:{version:1,unlocked:{}},records:{version:1,best:[]},totals:{version:1,totals:{},sports:[]}};}
function epoch(app){return app.findRecordsByFilter('pace_v2_settings','','',1,0)[0].getString('epoch');}
function legacy(){return $os.getenv('PACE_ENABLE_LEGACY_API')==='1';}
function current(app,owner){const rows=app.findRecordsByFilter('pace_v2_state','owner={:owner}','',1,0,{owner});return rows.length?rows[0]:null;}
function state(app,owner){const row=current(app,owner);return {epoch:epoch(app),revision:row?row.getInt('revision'):0,derived:row?JSON.parse(row.getString('derived')):empty()};}
function checkEpoch(app,value){if(value!==epoch(app))throw new ApiError(409,'История обновлена. Повтори синхронизацию.',{reason:'epoch'});}
function session(value){if(typeof value!=='string'||!/^[A-Za-z0-9:_-]{1,128}$/.test(value))throw new BadRequestError('Некорректная сессия');return value;}
function hash(value){if(typeof value!=='string'||!/^[a-f0-9]{64}$/.test(value))throw new BadRequestError('Некорректный digest');return value;}
function integer(value,min,max){if(!Number.isSafeInteger(value)||value<min||value>max)throw new BadRequestError('Некорректное число');return value;}
function existing(app,owner,id){const rows=app.findRecordsByFilter('pace_v2_workouts','owner={:owner} && sessionId={:id}','',1,0,{owner,id});return rows.length?rows[0]:null;}
function bytes(value){return toBytes(value).length;}
function validatePart(kind,dataJson){
  if(!kinds.includes(kind)||typeof dataJson!=='string'||bytes(dataJson)>131072)throw new BadRequestError('Некорректная телеметрия');
  let rows;try{rows=JSON.parse(dataJson);}catch(_){throw new BadRequestError('Некорректный JSON телеметрии');}
  if(!Array.isArray(rows)||rows.length===0||rows.length>500)throw new BadRequestError('Некорректный размер части');
  for(const p of rows){
    if(!p||typeof p!=='object')throw new BadRequestError('Некорректный отсчёт');
    if(kind==='heartRateSamples'){
      if(!Number.isSafeInteger(p.bpm)||p.bpm<1||p.bpm>254||!Number.isFinite(Date.parse(p.at)))throw new BadRequestError('Некорректный пульсовой отсчёт');
    }else{
      if(!Number.isFinite(p.latitude)||!Number.isFinite(p.longitude)||Math.abs(p.latitude)>90||Math.abs(p.longitude)>180||(p.timestamp!==undefined&&!Number.isFinite(Date.parse(p.timestamp))))throw new BadRequestError('Некорректная GPS-точка');
      if(p.accuracy!==undefined&&(!Number.isFinite(p.accuracy)||p.accuracy<0))throw new BadRequestError('Некорректная точность');
    }
  }
}
function stage(e,body){
  const owner=e.auth.id,id=session(body.sessionId),upload=hash(body.uploadId),part=integer(body.part,0,1023),digest=hash(body.digest);
  validatePart(body.kind,body.dataJson);
  if($security.sha256(body.dataJson)!==digest)throw new BadRequestError('Повреждена часть телеметрии');
  e.app.runInTransaction(app=>{
    checkEpoch(app,body.epoch);
    const matches=app.findRecordsByFilter('pace_v2_telemetry','owner={:owner} && sessionId={:id} && uploadId={:upload} && kind={:kind} && part={:part}','',1,0,{owner,id,upload,kind:body.kind,part});
    if(matches.length){if(matches[0].getString('digest')!==digest)throw new ApiError(409,'Часть уже существует с другими данными',{reason:'collision'});return;}
    const old=existing(app,owner,id);
    if(old)throw new ApiError(409,'Тренировка уже сохранена',{reason:'collision'});
    const pending=app.findRecordsByFilter('pace_v2_telemetry','owner={:owner} && published=false','',0,0,{owner});
    if(pending.reduce((n,r)=>n+bytes(r.getString('dataJson')),0)+bytes(body.dataJson)>67108864)throw new ApiError(413,'Слишком много незавершённых загрузок');
    const row=new Record(app.findCollectionByNameOrId('pace_v2_telemetry'));
    for(const [key,value] of Object.entries({owner,sessionId:id,uploadId:upload,kind:body.kind,part,dataJson:body.dataJson,digest,published:false}))row.set(key,value);
    app.save(row);
  });return e.json(200,{digest});
}
function manifest(app,owner,id,raw){
  if(!raw||!Array.isArray(raw.parts)||raw.parts.length>2048)throw new BadRequestError('Некорректный manifest');
  const upload=hash(raw.uploadId),seen=new Set(),counts={};const rows=[];
  for(const entry of raw.parts){
    if(!entry||!kinds.includes(entry.kind))throw new BadRequestError('Некорректная категория телеметрии');
    const part=integer(entry.part,0,1023),digest=hash(entry.digest),key=entry.kind+':'+part;
    if(seen.has(key))throw new BadRequestError('Повторная часть');seen.add(key);counts[entry.kind]=(counts[entry.kind]||0)+1;
    const matches=app.findRecordsByFilter('pace_v2_telemetry','owner={:owner} && sessionId={:id} && uploadId={:upload} && kind={:kind} && part={:part}','',1,0,{owner,id,upload,kind:entry.kind,part});
    if(!matches.length||matches[0].getString('digest')!==digest)throw new BadRequestError('Телеметрия загружена не полностью');rows.push(matches[0]);
  }
  for(const kind of kinds){for(let i=0;i<(counts[kind]||0);i++)if(!seen.has(kind+':'+i))throw new BadRequestError('Пропущена часть телеметрии');}
  return rows;
}
function validateSummary(s){
  if(!s||typeof s!=='object'||bytes(JSON.stringify(s))>131072||kinds.some(k=>s[k]!==undefined))throw new BadRequestError('Некорректные показатели');
  session(s.sessionId);
  if(!Number.isFinite(Date.parse(s.date))||typeof s.sport!=='string'||s.sport.length>40||!Number.isFinite(s.distance)||s.distance<0||!Number.isSafeInteger(s.durationSeconds)||s.durationSeconds<0||!Number.isSafeInteger(s.xp)||s.xp<0)throw new BadRequestError('Некорректная тренировка');
  if(s.elevationGain!==undefined&&s.elevationGain!==null&&(!Number.isFinite(s.elevationGain)||s.elevationGain<0))throw new BadRequestError('Некорректный набор');
}
function validateDerived(before,after,s){
  if(!after||after.version!==2||!Number.isSafeInteger(after.xp)||after.xp!==before.xp+s.xp||!after.achievements||!after.records||!after.totals||bytes(JSON.stringify(after))>131072)throw new BadRequestError('Некорректный прогресс');
  // Reward calculation remains client-side in this phase. Enforce arithmetic and immutable sessions.
}
function commit(e,body){
  const owner=e.auth.id,s=body.summary;validateSummary(s);const fingerprint=hash(body.fingerprint);let response;
  e.app.runInTransaction(app=>{
    checkEpoch(app,body.epoch);
    const before=state(app,owner),old=existing(app,owner,s.sessionId);
    if(old){
      if(old.getString('fingerprint')!==fingerprint)throw new ApiError(409,'Сессия уже содержит другую тренировку',{reason:'collision'});
      response={...before,summary:JSON.parse(old.getString('summary')),fingerprint:old.getString('fingerprint'),duplicate:true};return;
    }
    if(integer(body.revision,0,Number.MAX_SAFE_INTEGER)!==before.revision)throw new ApiError(409,'Прогресс обновлён на другом устройстве',{reason:'revision'});
    validateDerived(before.derived,body.derived,s);
    const chunks=manifest(app,owner,s.sessionId,body.manifest),revision=before.revision+1;
    const row=new Record(app.findCollectionByNameOrId('pace_v2_workouts'));
    for(const [key,value] of Object.entries({owner,sessionId:s.sessionId,revision,summary:s,fingerprint,manifest:body.manifest}))row.set(key,value);
    app.save(row);
    require(`${__hooks}/lib/garmin_receipts.js`).issue(app,owner,s,chunks,before.epoch);
    const progress=current(app,owner)||new Record(app.findCollectionByNameOrId('pace_v2_state'));
    progress.set('owner',owner);progress.set('revision',revision);progress.set('derived',body.derived);app.save(progress);
    for(const chunk of chunks){chunk.set('published',true);app.save(chunk);}
    // Cache competition scores from lightweight summaries, never from GPS/HR chunks.
    const scoring=require(`${__hooks}/lib/competition.js`);scoring.sync(app,owner,scoring.snapshot(app,owner));
    response={epoch:before.epoch,revision,derived:body.derived,summary:s,fingerprint,duplicate:false};
  });return e.json(200,response);
}
function list(e,body){
  checkEpoch(e.app,body.epoch);const after=integer(body.after ?? 0,0,Number.MAX_SAFE_INTEGER),through=integer(body.through,after,Number.MAX_SAFE_INTEGER);
  const rows=e.app.findRecordsByFilter('pace_v2_workouts','owner={:owner} && revision>{:after} && revision<={:through}','revision',21,0,{owner:e.auth.id,after,through});
  const page=rows.slice(0,20);
  return e.json(200,{epoch:body.epoch,items:page.map(r=>({revision:r.getInt('revision'),fingerprint:r.getString('fingerprint'),summary:JSON.parse(r.getString('summary'))})),hasMore:rows.length>20,next:page.length?page[page.length-1].getInt('revision'):after});
}
function detail(e,body){
  checkEpoch(e.app,body.epoch);const id=session(body.sessionId),offset=integer(body.offset ?? 0,0,4096),row=existing(e.app,e.auth.id,id);
  if(!row)throw new NotFoundError('Тренировка не найдена');
  const manifest=JSON.parse(row.getString('manifest')),parts=manifest.parts.slice(offset,offset+4),out=[];
  for(const part of parts){
    const r=e.app.findRecordsByFilter('pace_v2_telemetry','owner={:owner} && sessionId={:id} && uploadId={:upload} && kind={:kind} && part={:part} && published=true','',1,0,{owner:e.auth.id,id,upload:manifest.uploadId,kind:part.kind,part:part.part});
    if(!r.length)throw new ApiError(503,'Телеметрия временно недоступна');
    out.push({...part,dataJson:r[0].getString('dataJson')});
  }
  return e.json(200,{summary:JSON.parse(row.getString('summary')),parts:out,next:offset+out.length,hasMore:offset+out.length<manifest.parts.length});
}
module.exports={state,legacy,empty,action:e=>{
  const body=e.requestInfo().body;
  if(body.action==='list')return list(e,body);
  if(body.action==='stage')return stage(e,body);
  if(body.action==='commit')return commit(e,body);
  if(body.action==='detail')return detail(e,body);
  if(body.action==='ackGarmin')return require(`${__hooks}/lib/garmin_receipts.js`).prune(e);
  throw new BadRequestError('Неизвестное действие');
}};
