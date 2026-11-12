"""Real isolated PocketBase scoring tests. SQL only shifts synthetic fixture dates."""
import os,json,secrets,socket,sqlite3,subprocess,tempfile,time
from contextlib import closing
from pathlib import Path
from test_support import prepare_test_database
from datetime import datetime,timedelta,timezone
from urllib.request import Request,urlopen
from urllib.error import HTTPError
ROOT=Path(__file__).resolve().parents[1]
checks=0
def check(value,label):
 global checks
 assert value,label
 checks+=1
def iso(value):return value.isoformat().replace('+00:00','Z')
with tempfile.TemporaryDirectory(prefix='pace-competition-') as folder:
 temp=Path(folder).resolve();dbpath=temp/'data/data.db';assert dbpath.is_relative_to(temp)
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 prepare_test_database(ROOT,temp)
 log=(temp/'server.log').open('wb')
 proc=subprocess.Popen([str(ROOT/'server/runtime/pocketbase.exe'),'serve',f'--http=127.0.0.1:{port}',f'--dir={temp/"data"}',f'--migrationsDir={ROOT/"server/pb_migrations"}',f'--hooksDir={ROOT/"server/pb_hooks"}'],env={**os.environ,'PACE_ENABLE_LEGACY_API':'1'},stdout=log,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 def req(method,path,body=None,token=None):
  headers={'Content-Type':'application/json'}
  if token:headers['Authorization']=token
  if body and 'identity' in body:headers['X-Real-IP']='192.0.2.'+body['identity'].split('@')[0].split('-')[-1]
  request=Request(f'http://127.0.0.1:{port}'+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
  try:
   with urlopen(request,timeout=10) as r:return r.status,json.loads(r.read())
  except HTTPError as e:return e.code,json.loads(e.read())
 def act(token,action,**body):return req('POST','/api/pace/community/action',{'action':action,**body},token)
 def progress(token,workouts,xp=9000):
  code,previous=req('GET','/api/pace/progress',token=token);assert code==200
  code,result=req('PUT','/api/pace/progress',{'revision':previous['revision'],'data':{'version':1,'xp':xp,'workouts':workouts,'achievements':{},'records':{}}},token)
  assert code==200,(code,result)
 def sql(query,args):
  with closing(sqlite3.connect(dbpath,timeout=10)) as db:
   with db:db.execute(query,args)
 try:
  for _ in range(100):
   try:
    if req('GET','/api/health')[0]==200:break
   except Exception:pass
   if proc.poll() is not None:raise AssertionError('Temporary migration/startup failed: '+(temp/'server.log').read_text(errors='replace')[-1500:])
   time.sleep(.1)
  else:raise AssertionError('temporary backend timeout')
  tokens=[]
  for i in range(1,4):
   email=f'score-fixture-{i}@invalid.example';password=secrets.token_urlsafe(24)
   assert req('POST','/api/collections/pace_users/records',{'email':email,'password':password,'passwordConfirm':password,'name':f'Athlete {i}'})[0]==200
   code,data=req('POST','/api/collections/pace_users/auth-with-password',{'identity':email,'password':password});assert code==200
   tokens.append(data['token'])
  owner,user,other=tokens
  progress(owner,[],65000);progress(user,[]);progress(other,[])
  code,club=act(owner,'createClub',name='Fixture club',description='Synthetic',sport='Бег');assert code==200;cid=club['id']
  assert act(user,'join',targetKind='club',id=cid)[0]==200
  now=datetime.now(timezone.utc).replace(microsecond=0)
  rule={'version':1,'metric':'distance','sex':'male','minDistanceKm':5,'minDurationSeconds':1800,'minAscentMeters':20,'minPaceSeconds':300,'maxPaceSeconds':450}
  payload={'name':'Fixture competition','description':'Synthetic','sport':'Бег','clubId':cid,'kind':'competition','audience':'open','startsAt':iso(now+timedelta(days=1)),'endsAt':iso(now+timedelta(days=2)),'scoring':rule}
  check(act(None,'results',id='a'*15)[0]==401,'anonymous results denied')
  check(act(owner,'createEvent',**{**payload,'scoring':None})[0]==400,'new competition needs rules')
  check(act(owner,'createEvent',**{**payload,'scoring':{**rule,'requireHeartRate':True}})[0]==400,'unapproved HR rule cannot be enabled')
  check(act(owner,'createEvent',**{**payload,'scoring':{**rule,'minPaceSeconds':500}})[0]==400,'inverted pace bounds denied')
  check(act(owner,'createEvent',**{**payload,'scoring':{**rule,'minDistanceKm':-1}})[0]==400,'negative condition denied')
  code,event=act(owner,'createEvent',**payload);check(code==200,'create scored event');eid=event['id']
  check(event['scoring']['metric']=='distance','rules visible before joining')
  check(act(user,'join',targetKind='event',id=eid)[0]==200,'participant joins')
  check(act(other,'join',targetKind='event',id=eid)[0]==200,'second participant joins')
  sql('UPDATE pace_events SET startsAt=?,endsAt=? WHERE id=?',(iso(now-timedelta(hours=3)),iso(now+timedelta(hours=1)),eid))
  sql('UPDATE pace_community_members SET joinedAt=? WHERE target=?',(iso(now-timedelta(hours=2,minutes=15)),eid))
  def workout(id,**changes):return {**{'sessionId':id,'date':iso(now-timedelta(hours=2)),'startedAt':iso(now-timedelta(hours=2)),'endedAt':iso(now-timedelta(hours=1)),'distance':10,'durationSeconds':3600,'elevationGain':30,'xp':100,'sport':'Бег','xpBreakdown':{'participantSex':'male'}},**changes}
  history=[workout('good'),workout('wrong-sport',sport='Велосипед'),workout('wrong-sex',xpBreakdown={'participantSex':'female'}),workout('short',distance=4),workout('no-end',endedAt=None),workout('no-ascent',elevationGain=None),workout('too-fast',durationSeconds=2000),workout('before-join',startedAt=iso(now-timedelta(hours=2,minutes=30))),workout('beyond-end',endedAt=iso(now+timedelta(hours=2))),workout('legacy-naive',startedAt='2026-11-12T12:00:00'),workout('outside',startedAt=iso(now-timedelta(days=1)))]
  progress(user,history)
  code,result=act(user,'results',id=eid)
  check(code==200 and result['mine']['score']==10000 and result['mine']['workouts']==1,'only qualifying workout scored')
  check(result['rows'][0]['rank']==1 and result['rows'][0]['me'],'own row and rank')
  check(result['mine']['excluded'].get('conditions')==2,'minimum distance and pace rejected')
  check(result['mine']['excluded'].get('beforeJoin')==1,'before membership rejected')
  check(result['mine']['excluded'].get('time')==2,'missing end and ambiguous timezone rejected')
  check(result['mine']['excluded'].get('period')==1,'outside end rejected')
  check(result['mine']['excluded'].get('ascent')==1,'missing ascent rejected')
  check(result['mine']['excluded'].get('sex')==1,'category snapshot enforced')
  check(result['mine']['excluded'].get('sport')==1,'sport enforced')
  progress(user,history)
  check(act(user,'results',id=eid)[1]['mine']['score']==10000,'repeated sync never doubles score')
  progress(other,[workout('other-good')])
  result=act(user,'results',id=eid)[1]
  check([r['rank'] for r in result['rows']]==[1,1],'equal scores share place')
  history.append(workout('good2',distance=20,durationSeconds=7200,endedAt=iso(now)))
  progress(user,history)
  result=act(user,'results',id=eid)[1]
  check(result['rows'][0]['score']==30000 and result['rows'][1]['rank']==2,'larger aggregate wins')
  public=json.dumps(result['rows'])
  check(all(value not in public for value in ['email','latitude','heartRateSamples','externalId','fixture-2@']), 'public rows contain no private training data')
  check(act(user,'results',id=eid,page=-1)[0]==400,'negative result page denied')
  check(act(user,'results',id=cid)[0]==404,'club cannot masquerade as competition')
  check(req('GET','/api/collections/pace_competition_scores/records',token=user)[0]==403,'direct score read locked')
  check(req('POST','/api/collections/pace_competition_scores/records',{'event':eid,'score':999999},user)[0]==403,'client cannot write score')
  for metric,expected in [('duration',10800),('ascent',60),('workouts',2)]:
   code,extra=act(owner,'createEvent',**{**payload,'scoring':{**rule,'metric':metric}});assert code==200
   extra_id=extra['id'];assert act(user,'join',targetKind='event',id=extra_id)[0]==200
   sql('UPDATE pace_events SET startsAt=?,endsAt=? WHERE id=?',(iso(now-timedelta(hours=3)),iso(now+timedelta(hours=1)),extra_id))
   sql('UPDATE pace_community_members SET joinedAt=? WHERE target=?',(iso(now-timedelta(hours=2,minutes=15)),extra_id))
   check(act(user,'results',id=extra_id)[1]['mine']['score']==expected,f'{metric} aggregate correct')
  code,closed=act(owner,'createEvent',**{**payload,'audience':'club'});assert code==200
  closed_id=closed['id']
  check(act(other,'results',id=closed_id)[0]==403,'club-only result privacy')
  check(act(user,'results',id=closed_id)[0]==200,'member may browse club-only results')
  check(act(user,'leave',targetKind='event',id=eid)[0]==200,'leaving scored competition')
  result=act(user,'results',id=eid)[1]
  check(result['mine'] is None and len(result['rows'])==1,'departed athlete removed from rankings')
  assert act(user,'join',targetKind='event',id=eid)[0]==200
  check(act(user,'results',id=eid)[1]['mine']['workouts']==0,'rejoining does not restore old workouts')
  print(f'COMPETITION_API_CHECKS_PASSED={checks}; synthetic temporary database only')
 finally:
  proc.terminate();proc.wait(timeout=10);log.close()
