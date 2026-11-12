import copy, io, struct, unittest, zipfile
from datetime import datetime, timezone, timedelta
from unittest.mock import patch
from collect_personal import eligible, activity_packet, collect, decode_messages, ImportProblem, instant, prune_inbox, read_receipts
import json, sqlite3, tempfile
from pathlib import Path
from contextlib import closing
from garmin_fit_sdk.crc_calculator import CrcCalculator

SINCE=datetime(2026,11,12,8,30,tzinfo=timezone.utc)
NOW=SINCE+timedelta(hours=6)

def summary(id=123,at=None):
 return {'activityId':id,'activityType':{'typeKey':'running'},'startTimeGMT':(at or SINCE+timedelta(hours=1)).replace(tzinfo=None).isoformat(sep=' '),'duration':3600,'distance':10000,'elevationGain':30,'averageHR':140,'maxHR':160}

def messages():
 start=SINCE+timedelta(hours=1)
 return {'file_id_mesgs':[{'type':'activity'}],'session_mesgs':[{'start_time':start,'total_distance':10000,'total_timer_time':3600,'total_elapsed_time':3600,'total_ascent':30}],
  'record_mesgs':[{'timestamp':start+timedelta(seconds=i),'heart_rate':140+i,'position_lat':10000+i*100,'position_long':20000,'altitude':30,'gps_accuracy':5} for i in range(3)]}

def fit_fixture():
 # Small independent binary FIT fixture exercises the official decoder and CRC.
 epoch=datetime(1989,12,31,tzinfo=timezone.utc)
 start=int(((SINCE+timedelta(hours=1))-epoch).total_seconds())
 data=bytearray()
 def definition(local,global_id,fields):
  data.extend(bytes([0x40|local,0,0])+struct.pack('<H',global_id)+bytes([len(fields)]))
  for f in fields: data.extend(bytes(f))
 definition(0,0,[(0,1,0),(1,2,0x84),(4,4,0x86)])
 data.extend(bytes([0])+struct.pack('<BHI',4,1,start))
 definition(1,18,[(2,4,0x86),(5,1,0),(7,4,0x86),(8,4,0x86),(9,4,0x86),(22,2,0x84)])
 data.extend(bytes([1])+struct.pack('<IBIIIH',start,1,3600000,3600000,1000000,30))
 definition(2,20,[(253,4,0x86),(0,4,0x85),(1,4,0x85),(3,1,2),(31,1,2)])
 for i in range(3): data.extend(bytes([2])+struct.pack('<IiiBB',start+i,10000+i*100,20000,140+i,5))
 header=struct.pack('<BBHI4s',12,0x20,2200,len(data),b'.FIT')
 content=bytearray(header+data)
 return bytes(content)+struct.pack('<H',CrcCalculator.calculate_crc(content,0,len(content)))

class CollectorTests(unittest.TestCase):
 def test_strict_cutoff_and_utc(self):
  self.assertFalse(eligible(summary(at=SINCE-timedelta(seconds=1)),SINCE,NOW))
  self.assertTrue(eligible(summary(at=SINCE),SINCE,NOW))
  self.assertFalse(eligible(summary(at=NOW+timedelta(seconds=1)),SINCE,NOW))
 def test_manual_and_unsupported_excluded(self):
  for flag in ['manualActivity','isManualActivity']:
   s=summary();s[flag]=True;self.assertFalse(eligible(s,SINCE,NOW))
  s=summary();s['activityType']['typeKey']='strength_training';self.assertFalse(eligible(s,SINCE,NOW))
 def test_full_hr_and_route_no_invented_accuracy(self):
  m=messages();del m['record_mesgs'][0]['gps_accuracy']
  p=activity_packet(summary(),m,SINCE,NOW,'a'*64)
  self.assertEqual(p['durationSeconds'],3600);self.assertEqual(p['distanceKm'],10)
  self.assertEqual(instant(p['endedAt'])-instant(p['startedAt']),timedelta(seconds=3600))
  self.assertEqual([s['bpm'] for s in p['heartRateSamples']],[140,141,142])
  self.assertNotIn('accuracy',p['route'][0]);self.assertEqual(p['route'][1]['accuracy'],5)
 def test_old_fit_cannot_masquerade_as_new_summary(self):
  m=messages();m['session_mesgs'][0]['start_time']=SINCE-timedelta(days=1)
  with self.assertRaises(ImportProblem):activity_packet(summary(),m,SINCE,NOW,'a'*64)
 def test_finish_time_preserves_pauses_and_is_not_invented(self):
  m=messages();m['session_mesgs'][0]['total_elapsed_time']=4200
  packet=activity_packet(summary(),m,SINCE,NOW,'a'*64)
  self.assertEqual((instant(packet['endedAt'])-instant(packet['startedAt'])).total_seconds(),4200)
  del m['session_mesgs'][0]['total_elapsed_time']
  self.assertNotIn('endedAt',activity_packet(summary(),m,SINCE,NOW,'a'*64))
 def test_multisport_and_bad_measurements_rejected(self):
  for mutate in [lambda m:m['session_mesgs'].append(m['session_mesgs'][0]),lambda m:m['session_mesgs'][0].update(total_distance=-1)]:
   m=messages();mutate(m)
   with self.assertRaises(ImportProblem):activity_packet(summary(),m,SINCE,NOW,'a'*64)
 def test_pause_breaks_record_segment(self):
  m=messages();m['event_mesgs']=[{'event':'timer','event_type':'stop','timestamp':m['record_mesgs'][0]['timestamp']}]
  p=activity_packet(summary(),m,SINCE,NOW,'a'*64)
  self.assertNotEqual(p['route'][0]['segment'],p['route'][1]['segment'])
 def test_real_sdk_crc_and_zip(self):
  content=fit_fixture();decoded,digest=decode_messages(content)
  p=activity_packet(summary(),decoded,SINCE,NOW,digest)
  self.assertEqual(len(p['heartRateSamples']),3);self.assertEqual(p['distanceKm'],10)
  archive=io.BytesIO()
  with zipfile.ZipFile(archive,'w') as z:z.writestr('Activity.fit',content)
  self.assertEqual(decode_messages(archive.getvalue())[1],digest)
  broken=bytearray(content);broken[-3]^=1
  with self.assertRaises(ImportProblem):decode_messages(bytes(broken))
 def test_old_and_duplicate_summaries_never_downloaded(self):
  class Client:
   downloads=[]
   def search(self,day,end,offset):return [summary(1,SINCE-timedelta(days=1)),summary(2),summary(3)]
   def download(self,id):self.downloads.append(id);return fit_fixture()
  client=Client();config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat(),'activities':[{'externalId':'2'}]}
  saved=[]
  result=collect(client,config,inbox,NOW,lambda value:saved.append(copy.deepcopy(value)))
  self.assertEqual(result[0],1);self.assertEqual(client.downloads,['3'])
  self.assertEqual(saved[-1]['activities'][-1]['externalId'],'3')
 def test_no_result_does_not_change_checkpoint(self):
  class Client:
   def search(self,*args):return []
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat(),'activities':[]}
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda value:self.fail('unnecessary write')),(0,0))
  self.assertEqual(config['sinceUtc'],SINCE.isoformat())
 def test_wrong_owner_queue_rejected(self):
  with self.assertRaises(ImportProblem):collect(None,{'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()},{'ownerId':'b'*15,'sinceUtc':SINCE.isoformat(),'activities':[]},NOW,lambda v:None)
 def test_acknowledged_ids_never_download_again_after_pruning(self):
  class Client:
   def search(self,*args):return [summary(1)]
   def download(self,id):raise AssertionError('receipt must skip download')
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={**config,'activities':[{'externalId':'1','fitSha256':'a'*64}]}
  saved=[]
  self.assertEqual(prune_inbox(config,inbox,{'1':'a'*64},lambda v:saved.append(copy.deepcopy(v))),1)
  self.assertEqual(inbox['activities'],[])
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda v:None,acknowledged={'1'}),(0,0))
 def test_prune_hash_mismatch_and_failed_replace_keep_source_packet(self):
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={**config,'activities':[{'externalId':'1','fitSha256':'a'*64}]}
  self.assertEqual(prune_inbox(config,inbox,{'1':'b'*64},lambda v:self.fail('changed FIT must remain')),0)
  original=copy.deepcopy(inbox)
  def fail(value):raise OSError('simulated atomic replace failure')
  with self.assertRaises(OSError):prune_inbox(config,inbox,{'1':'a'*64},fail)
  self.assertEqual(inbox,original)
  self.assertEqual(prune_inbox(config,inbox,{'1':'a'*64},lambda v:None),1)
 def test_full_queue_is_ready_to_drain_instead_of_failing_refresh(self):
  class Client:
   def search(self,*args):return [summary(999)]
   def download(self,id):raise AssertionError('must apply backpressure first')
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={**config,'activities':[{'externalId':str(i)} for i in range(200)]}
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda v:self.fail('queue must remain')),(0,0))
 def test_capacity_failure_does_not_append_or_skip_unstored_packet(self):
  class Client:
   def search(self,*args):return [summary(999)]
   def download(self,id):return fit_fixture()
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()}
  inbox={**config,'activities':[{'externalId':'1','padding':'x'*(30*1024*1024-500)}]}
  self.assertLess(len(json.dumps(inbox,separators=(',',':')).encode()),30*1024*1024)
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda v:self.fail('over-capacity write')),(0,0))
  self.assertEqual(len(inbox['activities']),1)
 def test_scan_resumes_beyond_first_thousand_summaries(self):
  class Client:
   def search(self,day,end,offset):return [summary(i+1) for i in range(offset,min(offset+50,1001))]
   def download(self,id):
    self_id=id
    if self_id!='1001':raise AssertionError('acknowledged FIT downloaded')
    return fit_fixture()
  config={'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()};inbox={**config,'activities':[]}
  ack={str(i) for i in range(1,1001)}
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda v:None,acknowledged=ack),(0,0))
  self.assertEqual(inbox['scanOffset'],1000)
  self.assertEqual(collect(Client(),config,inbox,NOW,lambda v:None,acknowledged=ack)[0],1)
  self.assertEqual(inbox['scanOffset'],0)
  self.assertEqual(inbox['activities'][0]['externalId'],'1001')
 def test_receipts_are_scoped_by_owner_epoch_and_cutoff(self):
  with tempfile.TemporaryDirectory(prefix='pace-garmin-receipts-') as temp:
   dbpath=Path(temp)/'data.db'
   with closing(sqlite3.connect(dbpath)) as db, db:
    db.execute('CREATE TABLE pace_v2_settings(epoch TEXT)');db.execute("INSERT INTO pace_v2_settings VALUES('new')")
    db.execute('CREATE TABLE pace_garmin_receipts(owner TEXT,epoch TEXT,sinceUtc TEXT,externalId TEXT,fitSha256 TEXT)')
    for owner,epoch,cutoff,id in [('a'*15,'new',SINCE.isoformat(),'1'),('b'*15,'new',SINCE.isoformat(),'2'),('a'*15,'old',SINCE.isoformat(),'3'),('a'*15,'new',NOW.isoformat(),'4')]:
     db.execute('INSERT INTO pace_garmin_receipts VALUES(?,?,?,?,?)',(owner,epoch,cutoff,id,'a'*64))
   self.assertEqual(read_receipts({'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()},dbpath),{'1':'a'*64})
   with self.assertRaises(ImportProblem):read_receipts({'ownerId':'a'*15,'sinceUtc':SINCE.isoformat()},Path(temp)/'missing.db')
   self.assertFalse((Path(temp)/'missing.db').exists())

if __name__=='__main__':unittest.main()
