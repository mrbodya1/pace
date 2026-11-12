// User-approved fresh start. Back up production pb_data before applying this migration.
migrate((app)=>{
  const locked={type:'base',listRule:null,viewRule:null,createRule:null,updateRule:null,deleteRule:null};
  const owner={name:'owner',type:'relation',collectionId:'paceaccounts001',required:true,maxSelect:1,cascadeDelete:true};
  const text=(name,max,required=false)=>({name,type:'text',max,required});
  app.save(new Collection({...locked,name:'pace_v2_settings',fields:[text('epoch',64,true)]}));
  const setting=new Record(app.findCollectionByNameOrId('pace_v2_settings'));setting.set('epoch','workouts-v2-20261112');app.save(setting);
  app.save(new Collection({...locked,name:'pace_v2_state',fields:[owner,{name:'revision',type:'number',onlyInt:true,min:0},{name:'derived',type:'json',required:true,maxSize:131072}],indexes:['CREATE UNIQUE INDEX idx_v2_state_owner ON pace_v2_state(owner)']}));
  app.save(new Collection({...locked,name:'pace_v2_workouts',fields:[owner,text('sessionId',128,true),{name:'revision',type:'number',required:true,onlyInt:true,min:1},{name:'summary',type:'json',required:true,maxSize:131072},text('fingerprint',64,true),{name:'manifest',type:'json',required:true,maxSize:262144}],indexes:['CREATE UNIQUE INDEX idx_v2_workout_session ON pace_v2_workouts(owner,sessionId)','CREATE UNIQUE INDEX idx_v2_workout_revision ON pace_v2_workouts(owner,revision)']}));
  app.save(new Collection({...locked,name:'pace_v2_telemetry',fields:[owner,text('sessionId',128,true),text('uploadId',64,true),{name:'kind',type:'select',values:['route','timedRoute','heartRateSamples'],maxSelect:1,required:true},{name:'part',type:'number',onlyInt:true,min:0},text('dataJson',131072,true),text('digest',64,true),{name:'published',type:'bool'},{name:'created',type:'autodate',onCreate:true}],indexes:['CREATE UNIQUE INDEX idx_v2_chunk ON pace_v2_telemetry(owner,sessionId,uploadId,kind,part)','CREATE INDEX idx_v2_pending_chunks ON pace_v2_telemetry(owner,published)']}));
  // The training history and its derived progress are intentionally reset; user profiles and clubs remain.
  for(const name of ['pace_progress','pace_competition_scores']){
    for(const record of app.findRecordsByFilter(name,'','',0,0))app.delete(record);
  }
},(app)=>{
  for(const name of ['pace_v2_telemetry','pace_v2_workouts','pace_v2_state','pace_v2_settings'])app.delete(app.findCollectionByNameOrId(name));
  // Deleted history is restored only from the checked pre-migration backup, never invented here.
});
