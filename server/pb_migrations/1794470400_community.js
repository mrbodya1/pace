// Private collections: all access is mediated by authenticated community hooks.
migrate((app) => {
  const locked = {type: 'base', listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null};
  const text = (name, max, required = false) => ({name, type: 'text', max, required});
  const owner = {name: 'owner', type: 'relation', collectionId: 'paceaccounts001', required: true, maxSelect: 1, cascadeDelete: true};
  app.save(new Collection({...locked, name: 'pace_clubs', fields: [owner, text('name', 80, true), text('description', 1500, true), text('city', 80), text('sport', 40, true), {name:'created',type:'autodate',onCreate:true}]}));
  app.save(new Collection({...locked, name: 'pace_events', fields: [owner, {name:'club',type:'relation',collectionId:app.findCollectionByNameOrId('pace_clubs').id,required:true,maxSelect:1,cascadeDelete:true}, text('name',80,true), text('description',1500,true), text('city',80),text('sport',40,true), {name:'kind',type:'select',values:['competition','event'],required:true,maxSelect:1}, {name:'audience',type:'select',values:['open','club'],required:true,maxSelect:1}, {name:'startsAt',type:'date',required:true}, {name:'endsAt',type:'date',required:true}, {name:'created',type:'autodate',onCreate:true}]}));
  for (const name of ['pace_clubs','pace_events']) {
    const collection = app.findCollectionByNameOrId(name);
    collection.fields.add(new TextField({name:'searchText',max:240}));
    app.save(collection);
  }
  app.save(new Collection({...locked, name:'pace_community_members', fields:[{name:'user',type:'relation',collectionId:'paceaccounts001',required:true,maxSelect:1,cascadeDelete:true}, {name:'kind',type:'select',values:['club','event'],required:true,maxSelect:1},text('target',15,true)], indexes:['CREATE UNIQUE INDEX idx_community_member ON pace_community_members (user, kind, target)', 'CREATE INDEX idx_community_target ON pace_community_members (kind, target)']}));
}, (app) => {
  for (const name of ['pace_community_members','pace_events','pace_clubs']) app.delete(app.findCollectionByNameOrId(name));
});
