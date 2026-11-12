migrate((app) => {
  const events = app.findCollectionByNameOrId('pace_events');
  events.fields.add(new JSONField({name:'scoring',maxSize:4096}));app.save(events);
  const members = app.findCollectionByNameOrId('pace_community_members');
  members.fields.add(new DateField({name:'joinedAt'}));app.save(members);
  for (const row of app.findRecordsByFilter('pace_community_members','','',0,0)) {
    row.set('joinedAt',new Date().toISOString());app.save(row);
  }
  app.save(new Collection({name:'pace_competition_scores',type:'base',listRule:null,viewRule:null,createRule:null,updateRule:null,deleteRule:null,fields:[
    {name:'event',type:'relation',collectionId:events.id,required:true,maxSelect:1,cascadeDelete:true},
    {name:'user',type:'relation',collectionId:'paceaccounts001',required:true,maxSelect:1,cascadeDelete:true},
    {name:'score',type:'number',onlyInt:true,min:0},
    {name:'workouts',type:'number',onlyInt:true,min:0},
    {name:'excluded',type:'json',maxSize:4096},
    {name:'updated',type:'autodate',onCreate:true,onUpdate:true}
  ],indexes:['CREATE UNIQUE INDEX idx_competition_user ON pace_competition_scores (event,user)','CREATE INDEX idx_competition_rank ON pace_competition_scores (event,score DESC)']}));
},(app)=>{
  app.delete(app.findCollectionByNameOrId('pace_competition_scores'));
  const events=app.findCollectionByNameOrId('pace_events');events.fields.removeByName('scoring');app.save(events);
  const members=app.findCollectionByNameOrId('pace_community_members');members.fields.removeByName('joinedAt');app.save(members);
});
