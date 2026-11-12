// A receipt is issued only within the workout commit, after matching the private
// source packet and every uploaded GPS/HR sample. No inbox writes in JS hooks.
function config(root) {
  try {return JSON.parse(toString($os.readFile(`${root}/import-config.json`)));}
  catch (_) {return null;}
}
function root() {return $os.getenv('PACE_GARMIN_RUNTIME') || $filepath.clean(`${__hooks}/../../../Runtime/Garmin`);}
function sameTime(a,b) {return typeof a==='string'&&typeof b==='string'&&Number.isFinite(Date.parse(a))&&Date.parse(a)===Date.parse(b);}
function point(a,b,heart) {
  if(!a||!b)return false;
  if(heart)return a.bpm===b.bpm&&sameTime(a.at,b.at);
  return a.latitude===b.latitude&&a.longitude===b.longitude&&
    (a.altitude??null)===(b.altitude??null)&&(a.accuracy??null)===(b.accuracy??null)&&
    (a.segment??0)===(b.segment??0)&&sameTime(a.timestamp,b.timestamp);
}
function issue(app,owner,s,chunks,epoch,options={}) {
  if(s.source!=='garmin-personal')return;
  const mismatch=message=>{if(options.soft)return false;throw new BadRequestError(message);};
  const base=root(),binding=options.binding||config(base);
  if(!binding||binding.version!==1||binding.ownerId!==owner||!Number.isFinite(Date.parse(binding.sinceUtc)))throw new BadRequestError('Garmin не привязан к этому аккаунту');
  let inbox=options.inbox;
  try {if(!inbox)inbox=JSON.parse(toString($os.readFile(`${base}/inbox.json`)));}
  catch(_){throw new ApiError(503,'Очередь Garmin временно недоступна');}
  if(inbox.ownerId!==owner||inbox.sinceUtc!==binding.sinceUtc||!Array.isArray(inbox.activities))throw new ApiError(503,'Привязка очереди Garmin изменилась');
  const packet=inbox.activities.find(p=>p.externalId===s.externalId);
  if(!packet||packet.source!=='garmin-personal'||!/^[0-9]{1,20}$/.test(s.externalId)||s.sessionId!=='garmin-personal:'+s.externalId||
    Date.parse(packet.startedAt)<Date.parse(binding.sinceUtc)||
    !/^[a-f0-9]{64}$/.test(packet.fitSha256)||s.sourceFitHash!==packet.fitSha256||
    !sameTime(s.startedAt,packet.startedAt)||!sameTime(s.date,packet.startedAt)||
    (packet.endedAt?!sameTime(s.endedAt,packet.endedAt):s.endedAt!=null)||
    s.sport!==packet.sport||s.distance!==packet.distanceKm||s.durationSeconds!==packet.durationSeconds||
    (s.elevationGain??null)!==(packet.elevationGain??null))return mismatch('Показатели не совпали с исходной тренировкой Garmin');
  for(const kind of ['route','timedRoute','heartRateSamples']) {
    const expected=(kind==='heartRateSamples'?packet.heartRateSamples:packet.route)||[];
    let offset=0;
    const ordered=chunks.filter(c=>c.getString('kind')===kind).sort((a,b)=>a.getInt('part')-b.getInt('part'));
    for(const chunk of ordered)for(const sample of JSON.parse(chunk.getString('dataJson'))) {
      if(!point(sample,expected[offset++],kind==='heartRateSamples'))return mismatch('Телеметрия Garmin загружена не полностью или изменена');
    }
    if(offset!==expected.length)return mismatch('Телеметрия Garmin загружена не полностью');
  }
  const receipt=new Record(app.findCollectionByNameOrId('pace_garmin_receipts'));
  for(const [key,value] of Object.entries({owner,epoch,sinceUtc:binding.sinceUtc,externalId:s.externalId,sessionId:s.sessionId,fitSha256:packet.fitSha256}))receipt.set(key,value);
  app.save(receipt);
  return true;
}
function acknowledged(app,owner,sinceUtc) {
  const epoch=app.findRecordsByFilter('pace_v2_settings','','',1,0)[0].getString('epoch');
  const rows=app.findRecordsByFilter('pace_garmin_receipts','owner={:owner} && epoch={:epoch} && sinceUtc={:sinceUtc}','',0,0,{owner,epoch,sinceUtc});
  return new Map(rows.map(r=>[r.getString('externalId'),r.getString('fitSha256')]));
}
function prune(e) {
  const binding=config(root());
  if(!binding||binding.version!==1||binding.ownerId!==e.auth.id)return e.json(200,{available:false,removed:0});
  // Upgrade-safe reconciliation for workouts committed before receipts existed.
  // Matching the entire original packet is mandatory; no acknowledgement by ID alone.
  let inbox;
  try {inbox=JSON.parse(toString($os.readFile(`${root()}/inbox.json`)));}
  catch(_){throw new ApiError(503,'Очередь Garmin временно недоступна');}
  if(inbox.ownerId!==e.auth.id||inbox.sinceUtc!==binding.sinceUtc||!Array.isArray(inbox.activities)||inbox.activities.length>200)throw new ApiError(503,'Привязка очереди Garmin изменилась');
  if(!inbox.activities.length)return e.json(200,{available:true,phase:'ready',removed:0});
  let removable=0;
  e.app.runInTransaction(app=>{
    const epoch=app.findRecordsByFilter('pace_v2_settings','','',1,0)[0].getString('epoch');
    const known=acknowledged(app,e.auth.id,binding.sinceUtc);
    for(const packet of inbox.activities) {
      if(known.has(packet.externalId)||!/^[0-9]{1,20}$/.test(packet.externalId))continue;
      const rows=app.findRecordsByFilter('pace_v2_workouts','owner={:owner} && sessionId={:id}','',1,0,{owner:e.auth.id,id:'garmin-personal:'+packet.externalId});
      if(!rows.length)continue;
      const manifest=JSON.parse(rows[0].getString('manifest')),chunks=[];
      for(const part of manifest.parts) {
        const found=app.findRecordsByFilter('pace_v2_telemetry','owner={:owner} && sessionId={:id} && uploadId={:upload} && kind={:kind} && part={:part} && published=true','',1,0,{owner:e.auth.id,id:'garmin-personal:'+packet.externalId,upload:manifest.uploadId,kind:part.kind,part:part.part});
        if(found.length&&found[0].getString('digest')===part.digest)chunks.push(found[0]);
      }
      if(chunks.length!==manifest.parts.length)continue;
      if(issue(app,e.auth.id,JSON.parse(rows[0].getString('summary')),chunks,epoch,{binding,inbox,soft:true}))known.set(packet.externalId,packet.fitSha256);
    }
    removable=inbox.activities.filter(p=>known.has(p.externalId)&&known.get(p.externalId)===p.fitSha256).length;
  });
  if(!removable)return e.json(200,{available:true,phase:'ready',removed:0});
  const launcher=$filepath.clean(`${__hooks}/../garmin/prune-personal-inbox.ps1`);
  let result;
  try {result=JSON.parse(toString($os.cmd('powershell.exe','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',launcher,'-Owner',e.auth.id).output()));}
  catch(_){throw new ApiError(503,'Очистка очереди Garmin временно недоступна');}
  return e.json(200,{available:true,phase:result.phase,removed:result.removed||0});
}
module.exports={issue,acknowledged,prune};
