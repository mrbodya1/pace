"""Isolated PocketBase test; never opens production pb_data or Garmin."""
import json, os, secrets, socket, subprocess, tempfile, time
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import HTTPError
ROOT=Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0,str(ROOT/'server'))
from test_support import prepare_test_database
build=ROOT/'build';build.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='garmin-api-',dir=build) as temporary:
 temp=Path(temporary).resolve();assert temp.is_relative_to(build.resolve())
 private=temp/'private';private.mkdir()
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 env=os.environ.copy();env['PACE_GARMIN_RUNTIME']=str(private)
 fixture=temp/'fake_refresh.py'
 fixture.write_text("import os,json,time\nfrom pathlib import Path\nfrom datetime import datetime,timezone\np=Path(os.environ['PACE_GARMIN_RUNTIME'])\nc=p/'calls'\nc.write_text(str(int(c.read_text())+1) if c.exists() else '1')\ntime.sleep(.3)\n(p/'refresh-state.json').write_text(json.dumps({'phase':'ready','startedAt':datetime.now(timezone.utc).isoformat(),'completedAt':datetime.now(timezone.utc).isoformat()}))\n",encoding='utf-8')
 import sys
 env['PACE_GARMIN_PYTHON']=sys.executable
 env['PACE_GARMIN_COLLECTOR']=str(fixture)
 prepare_test_database(ROOT,temp)
 log=(temp/'pb.log').open('wb')
 proc=subprocess.Popen([str(ROOT/'server/runtime/pocketbase.exe'),'serve',f'--http=127.0.0.1:{port}',f'--dir={temp / "data"}',f'--migrationsDir={ROOT / "server/pb_migrations"}',f'--hooksDir={ROOT / "server/pb_hooks"}'],env=env,stdout=log,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 def req(method,path,body=None,token=None):
  headers={'Content-Type':'application/json'}
  if token:headers['Authorization']=token
  request=Request(f'http://127.0.0.1:{port}'+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
  try:
   with urlopen(request,timeout=8) as response:return response.status,json.loads(response.read())
  except HTTPError as error:return error.code,json.loads(error.read())
 try:
  for attempt in range(100):
   try:
    if req('GET','/api/health')[0]==200:break
   except Exception:time.sleep(.1)
  else:raise RuntimeError('temporary backend not ready')
  accounts=[];password=secrets.token_urlsafe(24)
  for email in ['fixture-owner@invalid.example','fixture-other@invalid.example']:
   code,record=req('POST','/api/collections/pace_users/records',{'email':email,'password':password,'passwordConfirm':password,'name':'Fixture'})
   assert code==200,code
   code,login=req('POST','/api/collections/pace_users/auth-with-password',{'identity':email,'password':password})
   assert code==200,code
   accounts.append((record['id'],login['token']))
  owner,token=accounts[0];other,other_token=accounts[1]
  config={'version':1,'ownerId':owner,'sinceUtc':'2026-11-12T08:30:00Z'}
  inbox={**config,'activities':[{'source':'garmin-personal','externalId':'123','startedAt':'2026-11-12T10:00:00Z'}]}
  (private/'import-config.json').write_text(json.dumps(config),encoding='utf-8')
  (private/'inbox.json').write_text(json.dumps(inbox),encoding='utf-8')
  assert req('GET','/api/pace/garmin')[0]==401
  assert req('POST','/api/pace/garmin/refresh',{})[0]==401
  assert req('POST','/api/pace/garmin/refresh',{},other_token)[0]==403
  assert not (private/'calls').exists()
  assert req('POST','/api/pace/garmin/refresh',{'force':'yes'},token)[0]==400
  code,refresh=req('POST','/api/pace/garmin/refresh',{'force':True},token)
  assert code==202 and refresh['phase'] in ['running','ready'],(code,refresh)
  assert req('POST','/api/pace/garmin/refresh',{'force':True},token)[0]==202
  for attempt in range(50):
   if req('GET','/api/pace/garmin',token=token)[1].get('refresh',{}).get('phase')=='ready':break
   time.sleep(.1)
  else:raise AssertionError('fake one-shot refresh did not finish')
  assert (private/'calls').read_text()=='1'
  time.sleep(.2)
  assert req('POST','/api/pace/garmin/refresh',{},token)[0]==202
  assert (private/'calls').read_text()=='1'

  code,result=req('GET','/api/pace/garmin',token=token)
  assert code==200 and result['available'] and len(result['activities'])==1,(code,result)
  code,result=req('GET','/api/pace/garmin',token=other_token)
  assert code==200 and result=={'available':False,'activities':[]},(code,result)
  inbox['activities'][0]['startedAt']='2026-11-11T10:00:00Z'
  (private/'inbox.json').write_text(json.dumps(inbox),encoding='utf-8')
  assert req('GET','/api/pace/garmin',token=token)[0]==503
  inbox['ownerId']=other
  (private/'inbox.json').write_text(json.dumps(inbox),encoding='utf-8')
  assert req('GET','/api/pace/garmin',token=token)[0]==503
  assert req('POST','/api/pace/garmin',{},token)[0] in [404,405]
  assert req('GET','/api/pace/garmin/status')[0]==401
  code,status=req('GET','/api/pace/garmin/status',token=token)
  assert code==200 and status['available'] and set(status)=={'available','refresh'}
  assert len(json.dumps(status))<256 and 'activities' not in status and owner not in json.dumps(status)
  assert req('GET','/api/pace/garmin/status',token=other_token)[1]=={'available':False,'refresh':{'phase':'idle'}}
  from datetime import datetime,timezone,timedelta
  now=datetime.now(timezone.utc).isoformat()
  (private/'refresh-state.json').write_text(json.dumps({'phase':'error','startedAt':now,'completedAt':now}),encoding='utf-8')
  assert req('POST','/api/pace/garmin/refresh',{},token)[1]['phase']=='error'
  assert req('POST','/api/pace/garmin/refresh',{'force':True},token)[1]['phase']=='error'
  assert (private/'calls').read_text()=='1'
  old=(datetime.now(timezone.utc)-timedelta(seconds=15)).isoformat()
  (private/'refresh-state.json').write_text(json.dumps({'phase':'error','startedAt':old,'completedAt':old}),encoding='utf-8')
  assert req('POST','/api/pace/garmin/refresh',{},token)[1]['phase']=='error'
  assert (private/'calls').read_text()=='1'
  code,retried=req('POST','/api/pace/garmin/refresh',{'force':True},token)
  assert code==202 and retried.get('phase')=='running',(code,retried)
  for attempt in range(50):
   if (private/'calls').read_text()=='2':break
   time.sleep(.1)
  else:raise AssertionError('manual retry did not launch after error cooldown')
  time.sleep(.5)
  print('GARMIN_INBOX_API_TESTS_PASSED=23; isolated temporary database; no real Garmin data')
 finally:
  proc.terminate();proc.wait(timeout=10);log.close()
