import copy, io, struct, unittest, zipfile
from datetime import datetime, timezone, timedelta
from unittest.mock import patch
from collect_personal import eligible, activity_packet, collect, decode_messages, ImportProblem, instant
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

if __name__=='__main__':unittest.main()
