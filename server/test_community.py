"""Community permissions/lifecycle using a fresh isolated PocketBase, no real users."""
import os,json, secrets, socket, subprocess, tempfile, time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from test_support import prepare_test_database
from urllib.request import Request, urlopen
from urllib.error import HTTPError
ROOT=Path(__file__).resolve().parents[1]
checked=0
def check(condition,label):
 global checked
 assert condition,label
 checked+=1

with tempfile.TemporaryDirectory(prefix='pace-community-') as folder:
 temp=Path(folder)
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 prepare_test_database(ROOT,temp)
 log=(temp/'pb.log').open('wb')
 proc=subprocess.Popen([str(ROOT/'server/runtime/pocketbase.exe'),'serve',f'--http=127.0.0.1:{port}',f'--dir={temp/"data"}',f'--migrationsDir={ROOT/"server/pb_migrations"}',f'--hooksDir={ROOT/"server/pb_hooks"}'],env={**os.environ,'PACE_ENABLE_LEGACY_API':'1'},stdout=log,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 def req(method,path,body=None,token=None):
  headers={'Content-Type':'application/json'}
  if body and 'identity' in body:
   headers['X-Real-IP']='192.0.2.'+str(1+int(body['identity'].split('-')[1].split('@')[0]))
  if token:headers['Authorization']=token
  request=Request(f'http://127.0.0.1:{port}'+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
  try:
   with urlopen(request,timeout=10) as response:return response.status,json.loads(response.read())
  except HTTPError as error:return error.code,json.loads(error.read())
 def act(token,action,**body):return req('POST','/api/pace/community/action',{'action':action,**body},token)
 def progress(token,xp):
  code,old=req('GET','/api/pace/progress',token=token)
  assert code==200
  code,_=req('PUT','/api/pace/progress',{'revision':old['revision'],'data':{'version':1,'xp':xp,'workouts':[],'achievements':{},'records':{}}},token)
  assert code==200
 try:
  for _ in range(100):
   try:
    if req('GET','/api/health')[0]==200:break
   except Exception:pass
   if proc.poll() is not None:raise AssertionError('Temporary PocketBase failed to start: '+(temp/'pb.log').read_text(errors='replace')[-1500:])
   time.sleep(.1)
  else:raise AssertionError('Temporary backend startup timeout')
  tokens=[]
  for index in range(3):
   email=f'community-{index}@invalid.example';password=secrets.token_urlsafe(24)
   code,_=req('POST','/api/collections/pace_users/records',{'email':email,'password':password,'passwordConfirm':password,'name':'Fixture'})
   assert code==200
   code,data=req('POST','/api/collections/pace_users/auth-with-password',{'identity':email,'password':password});assert code==200,(code,data)
   tokens.append(data['token'])
  owner,user,other=tokens
  check(req('GET','/api/pace/community')[0]==401,'anonymous read denied')
  check(act(None,'createClub')[0]==401,'anonymous mutation denied')
  club={'name':'Fixture club','description':'Only synthetic data','sport':'Бег','city':'Fixture city'}
  progress(owner,64999)
  check(act(owner,'createClub',**club)[0]==403,'level10 exact lower boundary')
  progress(owner,65000)
  code,created=act(owner,'createClub',**club)
  check(code==200,'owner creates club: '+str(code))
  cid=created['id']
  check(created['joined'] and created['owner'] and created['members']==1,'owner is member')
  check(act(owner,'leave',targetKind='club',id=cid)[0]==400,'owner cannot leave')
  check(act(user,'join',targetKind='club',id=cid)[0]==403,'newcomer cannot join club')
  progress(user,8999)
  check(act(user,'join',targetKind='club',id=cid)[0]==403,'club exact lower boundary')
  progress(user,9000)
  check(act(user,'join',targetKind='club',id=cid)[0]==200,'level5 can join')
  check(act(user,'join',targetKind='club',id=cid)[1]['members']==2,'joining idempotent')
  start=datetime.now(timezone.utc)+timedelta(days=1)
  event={**club,'clubId':cid,'kind':'competition','audience':'open','startsAt':start.isoformat(),'endsAt':(start+timedelta(hours=2)).isoformat(),'scoring':{'version':1,'metric':'distance'}}
  check(act(user,'createEvent',**event)[0]==403,'member cannot create event')
  check(act(other,'createEvent',**event)[0]==403,'outsider cannot create event')
  check(act(owner,'createEvent',**{**event,'endsAt':start.isoformat()})[0]==400,'dates validated')
  check(act(owner,'createEvent',**{**event,'sport':'unknown'})[0]==400,'sport validated')
  check(act(owner,'createEvent',**{**event,'kind':'event'})[0]==400,'club meetings cannot be public')
  code,created=act(owner,'createEvent',**event)
  check(code==200,'owner creates competition: '+str(code));eid=created['id']
  progress(other,999)
  check(act(other,'join',targetKind='event',id=eid)[0]==403,'competition exact lower boundary')
  progress(other,1000)
  check(act(other,'join',targetKind='event',id=eid)[0]==200,'level2 can join open competition')
  check(act(other,'join',targetKind='event',id=eid)[1]['members']==1,'event joining idempotent')
  code,meeting=act(owner,'createEvent',**{**event,'kind':'event','audience':'club'})
  check(code==200,'club meeting created');mid=meeting['id']
  check(act(other,'join',targetKind='event',id=mid)[0]==403,'level2 cannot join club meeting')
  progress(other,9000)
  check(act(other,'join',targetKind='event',id=mid)[0]==403,'level5 outsider cannot join club meeting')
  check(act(user,'join',targetKind='event',id=mid)[0]==200,'club member joins meeting')
  check(act(user,'leave',targetKind='club',id=cid)[0]==200,'club departure works')
  code,data=req('GET','/api/pace/community',token=user)
  check(code==200 and not next(e for e in data['events'] if e['id']==mid)['joined'],'club departure cancels club-only participation')
  check('email' not in json.dumps(data) and 'ownerId' not in json.dumps(data),'feed contains no emails or private owner IDs')
  check(req('GET','/api/collections/pace_clubs/records',token=user)[0]==403,'direct collection listing locked')
  check(req('POST','/api/collections/pace_clubs/records',club,user)[0]==403,'direct creation locked')
  check(act(user,'join',targetKind='other',id=cid)[0]==400,'invalid category rejected')
  check(act(user,'join',targetKind='club',id='x OR 1=1')[0]==400,'identifier injection rejected')
  check(act(owner,'createClub',**{**club,'name':' '*4})[0]==400,'blank name rejected')
  check(act(owner,'createClub',**{**club,'description':'a'*1501})[0]==400,'long description rejected')
  check(act(owner,'list',page=-1)[0]==400,'negative pagination denied')
  check(act(owner,'list',page=0)[1]['page']==0,'pagination works')
  check(act(owner,'unsupported')[0]==400,'unknown action denied')
  code,cyrillic=act(owner,'createClub',**{**club,'name':'БЕГОВОЙ КЛУБ'})
  check(code==200,'Cyrillic fixture created')
  check(len(act(user,'list',page=0,search='беговой')[1]['clubs'])==1,'case-insensitive Cyrillic search')
  check(act(user,'list',page=0,mine=True)[1]['clubs']==[],'mine filter excludes left clubs')
  check(len(act(owner,'list',page=0,mine=True)[1]['clubs'])==2,'owned clubs included in mine')
  check(act(owner,'list',page=0,mine='yes')[0]==400,'filter type checked')
  for index in range(21):
   assert act(owner,'createClub',**{**club,'name':f'Pagination fixture {index}'})[0]==200
  first=act(owner,'list',page=0)[1];second=act(owner,'list',page=1)[1]
  check(first['hasMore'] and len(first['clubs'])==20 and len(second['clubs'])==3,'twenty-item pagination')
  check(not ({e['id'] for e in first['clubs']} & {e['id'] for e in second['clubs']}),'pagination has no duplicates')
  check(len(first['ownedClubs'])==23,'older owned clubs remain available to event form')
  print(f'COMMUNITY_API_CHECKS_PASSED={checked}; temporary database only')
 finally:
  proc.terminate();proc.wait(timeout=10);log.close()
