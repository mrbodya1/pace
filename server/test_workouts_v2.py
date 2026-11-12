"""V2 API tests on a new temporary PocketBase; never touches live data or Garmin."""
import json,secrets,socket,subprocess,tempfile,time,hashlib,sqlite3
from datetime import datetime,timedelta,timezone
from contextlib import closing
from pathlib import Path
from test_support import prepare_test_database
from urllib.request import Request,urlopen
from urllib.error import HTTPError
ROOT=Path(__file__).resolve().parents[1]
checked=0
def check(value,label):
 global checked
 assert value,label
 checked+=1
def compact(value):return json.dumps(value,separators=(',',':'),ensure_ascii=False)
def digest(text):return hashlib.sha256(text.encode()).hexdigest()
def empty():return {'version':2,'xp':0,'achievements':{'version':1,'unlocked':{}},'records':{'version':1,'best':[]},'totals':{'version':1,'totals':{},'sports':[]}}
with tempfile.TemporaryDirectory(prefix='pace-workouts-v2-') as folder:
 temp=Path(folder)
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 prepare_test_database(ROOT,temp)
 log=(temp/'server.log').open('wb')
 proc=subprocess.Popen([str(ROOT/'server/runtime/pocketbase.exe'),'serve',f'--http=127.0.0.1:{port}',f'--dir={temp/"data"}',f'--migrationsDir={ROOT/"server/pb_migrations"}',f'--hooksDir={ROOT/"server/pb_hooks"}'],stdout=log,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 def req(method,path,body=None,token=None):
  headers={'Content-Type':'application/json'}
  if token:headers['Authorization']=token
  request=Request(f'http://127.0.0.1:{port}'+path,data=None if body is None else compact(body).encode(),headers=headers,method=method)
  for attempt in range(30):
   try:
    with urlopen(request,timeout=15) as r:return r.status,json.loads(r.read())
   except HTTPError as e:
    if e.code==429 and attempt<29:
     e.close();time.sleep(1);continue
    return e.code,json.loads(e.read())
 def state(token):
  code,data=req('GET','/api/pace/v2/state',token=token);assert code==200,(code,data)
  return data
 def action(token,action,**body):return req('POST','/api/pace/v2/workouts',{'action':action,**body},token)
 try:
  for _ in range(100):
   try:
    if req('GET','/api/health')[0]==200:break
   except Exception:pass
   if proc.poll() is not None:raise AssertionError('Temporary migration failed: '+(temp/'server.log').read_text(errors='replace')[-1500:])
   time.sleep(.1)
  else:raise AssertionError('Temporary startup timeout')
  tokens=[]
  for i in range(2):
   email=f'v2-{i}@invalid.example';password=secrets.token_urlsafe(24)
   assert req('POST','/api/collections/pace_users/records',{'email':email,'password':password,'passwordConfirm':password,'name':'Fixture'})[0]==200
   code,data=req('POST','/api/collections/pace_users/auth-with-password',{'identity':email,'password':password});assert code==200
   tokens.append(data['token'])
  owner,other=tokens
  check(req('GET','/api/pace/v2/state')[0]==401,'anonymous state denied')
  check(action(None,'list')[0]==401,'anonymous action denied')
  first=state(owner);epoch=first['epoch']
  check(first['revision']==0 and first['derived']['xp']==0,'fresh state is empty')
  check('workouts' not in first['derived'],'state never contains workout history')
  check(req('GET','/api/pace/progress',token=owner)[0]==426,'legacy read requires upgrade')
  check(req('PUT','/api/pace/progress',{'revision':0,'data':{}},owner)[0]==426,'legacy upload cannot resurrect deleted history')
  check(action(owner,'list',epoch='old',through=0)[0]==409,'wrong epoch rejected')
  check(action(owner,'list',epoch=epoch,after=-1,through=0)[0]==400,'negative cursor rejected')
  s={'sessionId':'phone:one','date':'2026-11-12T12:00:00Z','startedAt':'2026-11-12T12:00:00Z','endedAt':'2026-11-12T13:00:00Z','sport':'Бег','durationSeconds':3600,'distance':10,'elevationGain':30,'xp':100}
  raw=compact([{'latitude':56.7,'longitude':60.6,'timestamp':'2026-11-12T12:00:00Z','accuracy':5}]);sha=digest(raw);upload=digest('fixture-upload')
  stage={'epoch':epoch,'sessionId':s['sessionId'],'uploadId':upload,'kind':'timedRoute','part':0,'dataJson':raw,'digest':sha}
  check(action(owner,'stage',**{**stage,'digest':'0'*64})[0]==400,'wrong chunk digest rejected')
  check(action(owner,'stage',**stage)[0]==200,'upload telemetry chunk')
  check(action(owner,'stage',**stage)[0]==200,'chunk retry is idempotent')
  check(action(owner,'stage',**{**stage,'dataJson':'[]','digest':digest('[]')})[0]==400,'empty chunk rejected')
  manifest={'uploadId':upload,'parts':[{'kind':'timedRoute','part':0,'digest':sha}]}
  derived=empty();derived['xp']=100
  commit={'epoch':epoch,'revision':0,'summary':s,'fingerprint':upload,'manifest':manifest,'derived':derived}
  check(action(owner,'commit',**{**commit,'manifest':{'uploadId':upload,'parts':[{'kind':'timedRoute','part':1,'digest':sha}]}})[0]==400,'missing chunk cannot publish')
  check(state(owner)['revision']==0,'failed commit is atomic')
  code,accepted=action(owner,'commit',**commit)
  check(code==200 and accepted['revision']==1,'summary and state committed')
  check(action(owner,'commit',**commit)[1]['duplicate'],'lost acknowledgement retry is idempotent')
  check(state(owner)['derived']['xp']==100,'duplicate earns no second XP')
  check(action(owner,'commit',**{**commit,'fingerprint':'a'*64})[0]==409,'session content collision rejected')
  check(state(other)['revision']==0,'other account has no shared history')
  check(action(other,'detail',epoch=epoch,sessionId=s['sessionId'])[0]==404,'other account cannot fetch telemetry')
  code,page=action(owner,'list',epoch=epoch,after=0,through=1)
  check(code==200 and len(page['items'])==1,'summary list works')
  check(all(k not in page['items'][0]['summary'] for k in ['route','timedRoute','heartRateSamples']),'list contains no traces')
  code,detail=action(owner,'detail',epoch=epoch,sessionId=s['sessionId'])
  check(code==200 and detail['parts'][0]['dataJson']==raw,'lazy telemetry matches original')
  check(detail['parts'][0]['digest']==sha,'detail carries integrity digest')
  for i in range(2,44):
   previous=state(owner);workout={**s,'sessionId':f'phone:{i}'};new={**previous['derived'],'xp':previous['derived']['xp']+100}
   body={'epoch':epoch,'revision':previous['revision'],'summary':workout,'fingerprint':digest(f'fixture-{i}'),'manifest':{'uploadId':digest(f'fixture-{i}'),'parts':[]},'derived':new}
   assert action(owner,'commit',**body)[0]==200
  pages=[];cursor=0
  while cursor<43:
   code,page=action(owner,'list',epoch=epoch,after=cursor,through=43);assert code==200
   check(len(page['items'])<=20,'page is bounded at20')
   pages.extend(item['summary']['sessionId'] for item in page['items']);cursor=page['next']
  check(len(pages)==43 and len(set(pages))==43,'pagination loses or duplicates no sessions')
  previous=state(owner)
  check(action(owner,'commit',**{**commit,'summary':{**s,'sessionId':'phone:stale'}})[0]==409,'CAS rejects stale revision')
  check(state(owner)==previous,'stale write changes nothing')
  for collection in ['pace_v2_settings','pace_v2_state','pace_v2_workouts','pace_v2_telemetry']:
   check(req('GET',f'/api/collections/{collection}/records',token=owner)[0]==403,'raw collection locked '+collection)
  # More than the former 32MiB snapshot limit, sent as individually bounded chunks.
  large_raw=compact([{'latitude':56.7,'longitude':60.6,'timestamp':'2026-11-12T12:00:00Z','padding':'x'*150}]*500)
  large_digest=digest(large_raw);stored_bytes=0
  for n in range(3):
   sid=f'volume:{n}';upload=digest(sid);parts=[]
   for part in range(100):
    code,reply=action(owner,'stage',epoch=epoch,sessionId=sid,uploadId=upload,kind='timedRoute',part=part,dataJson=large_raw,digest=large_digest)
    assert code==200,(n,part,code,reply)
    parts.append({'kind':'timedRoute','part':part,'digest':large_digest});stored_bytes+=len(large_raw.encode())
   previous=state(owner)
   assert action(owner,'commit',epoch=epoch,revision=previous['revision'],summary={**s,'sessionId':sid},fingerprint=upload,manifest={'uploadId':upload,'parts':parts},derived={**previous['derived'],'xp':previous['derived']['xp']+100})[0]==200
  check(stored_bytes>33554432,'telemetry history exceeds former32MiB limit')
  code,page=action(owner,'list',epoch=epoch,after=43,through=46)
  check(code==200 and len(page['items'])==3 and len(compact(page).encode())<16384,'large traces never enter summary page')
  code,detail=action(owner,'detail',epoch=epoch,sessionId='volume:2')
  check(code==200 and len(detail['parts'])==4 and detail['hasMore'],'large telemetry detail stays paginated')
  def community(action,**body):return req('POST','/api/pace/community/action',{'action':action,**body},owner)
  check(community('createClub',name='V2 fixture',description='Synthetic',sport='Бег')[0]==403,'V2 XP enforces club threshold')
  previous=state(owner);sid='v2:threshold';fp=digest(sid)
  assert action(owner,'commit',epoch=epoch,revision=previous['revision'],summary={**s,'sessionId':sid,'xp':65000},fingerprint=fp,manifest={'uploadId':fp,'parts':[]},derived={**previous['derived'],'xp':previous['derived']['xp']+65000})[0]==200
  code,club=community('createClub',name='V2 fixture',description='Synthetic',sport='Бег')
  check(code==200,'community reads new V2 XP')
  now=datetime.now(timezone.utc).replace(microsecond=0)
  iso=lambda value:value.isoformat().replace('+00:00','Z')
  code,event=community('createEvent',name='V2 competition',description='Synthetic',sport='Бег',clubId=club['id'],kind='competition',audience='open',startsAt=iso(now+timedelta(days=1)),endsAt=iso(now+timedelta(days=2)),scoring={'version':1,'metric':'distance','sex':'any'})
  assert code==200
  check(community('join',targetKind='event',id=event['id'])[0]==200,'V2 level permits participation')
  # Shift only this temporary fixture, so a completed training can be tested now.
  with closing(sqlite3.connect(temp/'data/data.db')) as fixture, fixture:
   fixture.execute('UPDATE pace_events SET startsAt=?,endsAt=? WHERE id=?',(iso(now-timedelta(hours=3)),iso(now+timedelta(hours=1)),event['id']))
   fixture.execute('UPDATE pace_community_members SET joinedAt=? WHERE target=?',(iso(now-timedelta(hours=2,minutes=15)),event['id']))
  previous=state(owner);sid='v2:scored';fp=digest(sid)
  body={'epoch':epoch,'revision':previous['revision'],'summary':{**s,'sessionId':sid,'date':iso(now-timedelta(hours=2)),'startedAt':iso(now-timedelta(hours=2)),'endedAt':iso(now-timedelta(hours=1))},'fingerprint':fp,'manifest':{'uploadId':fp,'parts':[]},'derived':{**previous['derived'],'xp':previous['derived']['xp']+100}}
  assert action(owner,'commit',**body)[0]==200
  result=community('results',id=event['id'])[1]
  check(result['mine']['score']==10000 and result['mine']['workouts']==1,'V2 commit updates competition from summaries')
  assert action(owner,'commit',**body)[1]['duplicate']
  check(community('results',id=event['id'])[1]['mine']['score']==10000,'retry never doubles competition score')
  print(f'WORKOUTS_V2_API_CHECKS_PASSED={checked}; temporary database only')
 finally:
  proc.terminate();proc.wait(timeout=10);log.close()
