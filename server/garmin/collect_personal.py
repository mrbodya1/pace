"""New-only collector for one local Garmin account; never logs secrets or payloads."""
from __future__ import annotations
import argparse, ctypes, hashlib, io, json, math, os, re, subprocess, sys, time, zipfile
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT.parent / 'Runtime' / 'Garmin'
BASE = 'https://personal.connectapi.garmin.com'
SPORTS = {'running':'Бег','trail_running':'Трейл','walking':'Ходьба','cycling':'Велосипед',
 'road_cycling':'Велосипед','road_biking':'Велосипед','mountain_biking':'Велосипед',
 'cross_country_skiing':'Лыжи','skate_skiing':'Лыжи','classic_cross_country_skiing':'Лыжи',
 'roller_skiing':'Роллеры','open_water_swimming':'Плавание'}
MAX_BYTES = 20 * 1024 * 1024

class ImportProblem(Exception): pass

def instant(value):
    if isinstance(value, datetime): result=value
    elif isinstance(value,str): result=datetime.fromisoformat(value.strip().replace('Z','+00:00'))
    else: raise ImportProblem('missing_timestamp')
    return result.replace(tzinfo=timezone.utc) if result.tzinfo is None else result.astimezone(timezone.utc)

def finite(value, default=None):
    return float(value) if isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value) else default

def utc(value): return instant(value).isoformat().replace('+00:00','Z')

def eligible(summary, since, now):
    try:
        start=instant(summary.get('startTimeGMT'))
        if not since <= start <= now: return False
        if summary.get('manualActivity') or summary.get('isManualActivity'): return False
        if not re.fullmatch(r'[0-9]{1,20}',str(summary.get('activityId',''))): return False
        return summary.get('activityType',{}).get('typeKey') in SPORTS
    except (ValueError,TypeError,ImportProblem): return False

def decode_messages(content):
    from garmin_fit_sdk import Decoder, Stream
    if content[:2] == b'PK':
        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            files=[f for f in archive.infolist() if not f.is_dir() and f.filename.lower().endswith('.fit')]
            if len(files)!=1 or files[0].file_size>MAX_BYTES: raise ImportProblem('ambiguous_or_large_fit')
            content=archive.read(files[0])
    if len(content)>MAX_BYTES: raise ImportProblem('large_fit')
    decoder=Decoder(Stream.from_byte_array(bytearray(content)))
    if not decoder.is_fit() or not decoder.check_integrity(): raise ImportProblem('invalid_fit_integrity')
    # Integrity checks consume the SDK stream; decode from a fresh stream.
    decoder=Decoder(Stream.from_byte_array(bytearray(content)))
    messages,errors=decoder.read()
    if errors: raise ImportProblem('fit_decode_failed')
    return messages,hashlib.sha256(content).hexdigest()

def activity_packet(summary, messages, since, now, fit_hash):
    if not eligible(summary,since,now): raise ImportProblem('excluded_activity')
    sessions=messages.get('session_mesgs',[])
    if len(sessions)!=1: raise ImportProblem('unsupported_multisport')
    session=sessions[0]
    start=instant(session.get('start_time'))
    if start < since or start > now or abs((start-instant(summary['startTimeGMT'])).total_seconds())>120:
        raise ImportProblem('fit_start_mismatch')
    file_ids=messages.get('file_id_mesgs',[])
    if not file_ids or file_ids[0].get('type') not in ('activity',4): raise ImportProblem('not_recorded_activity')
    distance=finite(session.get('total_distance'),finite(summary.get('distance')))
    duration=finite(session.get('total_timer_time'),finite(summary.get('duration')))
    elevation=finite(session.get('total_ascent'),finite(summary.get('elevationGain')))
    if distance is None or distance<50 or duration is None or duration<=0: raise ImportProblem('too_short_or_invalid')
    if elevation is not None and elevation<0: raise ImportProblem('invalid_elevation')
    elapsed=finite(session.get('total_elapsed_time'))
    if elapsed is not None and elapsed < duration-1: raise ImportProblem('invalid_elapsed_time')
    end=start+timedelta(seconds=elapsed if elapsed is not None else duration)
    if end>now+timedelta(minutes=5): raise ImportProblem('unfinished_activity')
    records=messages.get('record_mesgs',[])
    if len(records)>100000: raise ImportProblem('too_many_samples')
    route=[]; heart=[]; segment=0; last_time=None
    stops=sorted(instant(e['timestamp']) for e in messages.get('event_mesgs',[])
                 if e.get('event') in ('timer',0) and e.get('event_type') in ('stop','stop_all',1,4) and e.get('timestamp'))
    for record in records:
        if not record.get('timestamp'): continue
        at=instant(record['timestamp'])
        if at < start or at>end+timedelta(seconds=5): continue
        hr=finite(record.get('heart_rate'))
        if hr is not None and 0<hr<255: heart.append({'at':utc(at),'bpm':round(hr)})
        lat=finite(record.get('position_lat')); lon=finite(record.get('position_long'))
        if lat is None or lon is None: continue
        lat=lat*180/(2**31); lon=lon*180/(2**31)
        if not -90<=lat<=90 or not -180<=lon<=180: continue
        if last_time is not None:
            if at<=last_time: continue
            if (at-last_time).total_seconds()>30 or any(last_time<=stop<at for stop in stops): segment+=1
        point={'latitude':lat,'longitude':lon,'timestamp':utc(at),'segment':segment}
        altitude=finite(record.get('enhanced_altitude'),finite(record.get('altitude')))
        accuracy=finite(record.get('gps_accuracy'))
        if altitude is not None: point['altitude']=altitude
        # Never invent GPS accuracy for record awards.
        if accuracy is not None and accuracy>0: point['accuracy']=accuracy
        route.append(point); last_time=at
    # Keep complete timestamps; do not silently resample for personal records.
    if len(route)>30000: raise ImportProblem('route_too_large')
    return {'source':'garmin-personal','externalId':str(summary['activityId']),
      'startedAt':utc(start),'sport':SPORTS[summary['activityType']['typeKey']],
      **({'endedAt':utc(end)} if elapsed is not None else {}),'distanceKm':distance/1000,'durationSeconds':math.floor(duration),
      'elevationGain':elevation,'route':route,'heartRateSamples':heart,
      'averageHeartRate':finite(summary.get('averageHR')),'maxHeartRate':finite(summary.get('maxHR')),
      'fitSha256':fit_hash,'receivedAt':utc(now)}

def decrypt_key(path):
    if os.name!='nt': raise ImportProblem('windows_required')
    class Blob(ctypes.Structure): _fields_=[('size',ctypes.c_ulong),('data',ctypes.POINTER(ctypes.c_ubyte))]
    encrypted=bytes.fromhex(path.read_text(encoding='utf-8-sig').strip())
    storage=(ctypes.c_ubyte*len(encrypted)).from_buffer_copy(encrypted)
    source=Blob(len(encrypted),storage); target=Blob()
    crypt=ctypes.WinDLL('crypt32',use_last_error=True); kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    crypt.CryptUnprotectData.argtypes=[ctypes.POINTER(Blob),ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(Blob)]
    kernel.LocalFree.argtypes=[ctypes.c_void_p]
    if not crypt.CryptUnprotectData(ctypes.byref(source),None,None,None,None,1,ctypes.byref(target)): raise ImportProblem('key_unavailable_for_windows_user')
    try: return ctypes.string_at(target.data,target.size).decode('utf-16-le')
    finally:
        ctypes.memset(target.data,0,target.size); kernel.LocalFree(target.data)

class Garmin:
    def __init__(self,key):
        self.token=None; self.created_at=time.monotonic()
        if re.search(r'[\x00-\x20"\\]',key): raise ImportProblem('invalid_key_format')
        raw=self.request('/personalapitoken-service/personal-api/personal-api-key/token',method='POST',authorization='ApiKey '+key)
        text=raw.decode('utf-8').strip()
        if re.fullmatch(r'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',text): self.token=text
        else:
            try:
                value=json.loads(text); self.token=value if isinstance(value,str) else value.get('access_token')
            except (ValueError,AttributeError): pass
        if not isinstance(self.token,str) or re.search(r'[\x00-\x20"\\]',self.token): raise ImportProblem('invalid_token_response')
    def request(self,path,method='GET',authorization=None):
        if not path.startswith(('/personalapitoken-service/','/activitylist-service/activities/search/activities?','/download-service/files/activity/')): raise ImportProblem('forbidden_endpoint')
        auth=authorization or 'Bearer '+self.token
        config=f'url = "{BASE}{path}"\nrequest = "{method}"\nheader = "Authorization: {auth}"\nsilent\nshow-error\nconnect-timeout = 8\nmax-time = 30\nmax-filesize = {MAX_BYTES}\nwrite-out = "\\n%{{http_code}}"\n'
        if method=='POST': config+='data = ""\n'
        binary=Path(os.environ['SystemRoot'])/'System32/curl.exe'
        try:
            result=subprocess.run([str(binary),'--config','-'],input=config.encode(),capture_output=True,timeout=35,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        except (OSError,subprocess.TimeoutExpired): raise ImportProblem('transport_unavailable') from None
        if result.returncode: raise ImportProblem('transport_code_'+str(result.returncode))
        body,sep,status=result.stdout.rpartition(b'\n')
        if not sep or status!=b'200': raise ImportProblem('garmin_http_'+status.decode('ascii',errors='ignore')[:3])
        if len(body)>MAX_BYTES: raise ImportProblem('response_too_large')
        return body
    def search(self,day,end,offset):
        query=urlencode({'startDate':day,'endDate':end,'start':offset,'limit':50,'sortOrder':'asc','excludeChildren':'true'})
        try: value=json.loads(self.request('/activitylist-service/activities/search/activities?'+query))
        except ValueError: raise ImportProblem('invalid_search_json') from None
        if not isinstance(value,list): raise ImportProblem('invalid_search_shape')
        return value
    def download(self,activity_id):
        if not re.fullmatch(r'[0-9]{1,20}',activity_id): raise ImportProblem('invalid_activity_id')
        return self.request('/download-service/files/activity/'+activity_id)

def atomic_json(path,value):
    temp=path.with_name(path.name+'.tmp')
    data=json.dumps(value,ensure_ascii=True,separators=(',',':'))
    if len(data.encode())>30*1024*1024: raise ImportProblem('inbox_capacity_reached')
    temp.write_text(data,encoding='utf-8'); os.replace(temp,path)

def collect(client,config,inbox,now,save,deadline=None):
    since=instant(config['sinceUtc'])
    if inbox.get('ownerId')!=config['ownerId'] or instant(inbox['sinceUtc'])!=since: raise ImportProblem('inbox_binding_mismatch')
    known={a['externalId'] for a in inbox['activities']}; added=0; skipped=0
    day=since.astimezone(timezone(timedelta(hours=5))).date().isoformat()
    today=now.astimezone(timezone(timedelta(hours=5))).date().isoformat()
    for page in range(20):
        if deadline is not None and time.monotonic()>=deadline: return added,skipped
        summaries=client.search(day,today,page*50)
        for item in summaries:
            if deadline is not None and time.monotonic()>=deadline: return added,skipped
            if not eligible(item,since,now): skipped+=1; continue
            activity_id=str(item['activityId'])
            if activity_id in known: continue
            if len(inbox['activities'])>=200: raise ImportProblem('inbox_capacity_reached')
            try:
                messages,digest=decode_messages(client.download(activity_id))
                packet=activity_packet(item,messages,since,now,digest)
            except ImportProblem as error:
                # Keep unsuccessful entries retryable; no IDs or payloads in logs.
                print('GARMIN_ACTIVITY_SKIPPED='+str(error),flush=True); skipped+=1; continue
            inbox['activities'].append(packet)
            save(inbox); known.add(activity_id); added+=1
        if len(summaries)<50: break
    return added,skipped

def run_once(client=None):
    import msvcrt
    lock=(PRIVATE/'collector.lock').open('a+b')
    try:
        lock.seek(0); lock.write(b'0'); lock.flush(); lock.seek(0)
        try: msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        except OSError: raise ImportProblem('collector_already_running') from None
        config=json.loads((PRIVATE/'import-config.json').read_text(encoding='utf-8-sig'))
        if config.get('version')!=1 or not re.fullmatch(r'[a-z0-9]{15}',config.get('ownerId','')): raise ImportProblem('invalid_binding')
        inbox=json.loads((PRIVATE/'inbox.json').read_text(encoding='utf-8-sig'))
        if client is None or time.monotonic()-client.created_at>23*3600:
            client=Garmin(decrypt_key(PRIVATE/'personal-api-key.dpapi'))
        added,skipped=collect(client,config,inbox,datetime.now(timezone.utc),lambda value:atomic_json(PRIVATE/'inbox.json',value),deadline=time.monotonic()+120)
        print(f'GARMIN_NEW_ONLY_OK added={added} skipped={skipped}',flush=True)
        return client
    finally: lock.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--refresh',action='store_true',help='One requested refresh, never periodic polling')
    args=parser.parse_args()
    state=PRIVATE/'refresh-state.json'
    started=utc(datetime.now(timezone.utc))
    atomic_json(state,{'phase':'running','startedAt':started,'pid':os.getpid()})
    try:
        run_once()
        atomic_json(state,{'phase':'ready','startedAt':started,'completedAt':utc(datetime.now(timezone.utc))})
    except ImportProblem as error:
        atomic_json(state,{'phase':'error','startedAt':started,'completedAt':utc(datetime.now(timezone.utc)),'code':str(error)})
        print('GARMIN_IMPORT_ERROR='+str(error),flush=True);sys.exit(1)
    except Exception:
        atomic_json(state,{'phase':'error','startedAt':started,'completedAt':utc(datetime.now(timezone.utc)),'code':'unexpected_error'})
        print('GARMIN_IMPORT_ERROR=unexpected_error_no_private_details_logged',flush=True);sys.exit(1)
