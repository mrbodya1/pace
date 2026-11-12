// Additive migration: existing workouts, profiles and Garmin binding are preserved.
migrate(app => {
  app.save(new Collection({name:'pace_garmin_receipts',type:'base',
    listRule:null,viewRule:null,createRule:null,updateRule:null,deleteRule:null,
    fields:[
      {name:'owner',type:'relation',collectionId:'paceaccounts001',required:true,maxSelect:1,cascadeDelete:true},
      ...['epoch','sinceUtc','externalId','sessionId','fitSha256'].map(name=>({name,type:'text',required:true,max:128})),
      {name:'created',type:'autodate',onCreate:true}
    ],indexes:['CREATE UNIQUE INDEX idx_garmin_receipt ON pace_garmin_receipts(owner,epoch,sinceUtc,externalId)']
  }));
},app=>app.delete(app.findCollectionByNameOrId('pace_garmin_receipts')));
