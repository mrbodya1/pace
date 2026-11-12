const sports = ['Все виды', 'Бег', 'Ходьба', 'Велосипед', 'Лыжи', 'Трейл', 'Роллеры', 'Плавание'];
function text(body, key, max, required = false) {
  if (body[key] === undefined && !required) return '';
  if (typeof body[key] !== 'string') throw new BadRequestError('Проверь поле: ' + key);
  const value = body[key].trim();
  if (value.length > max || (required && !value)) throw new BadRequestError('Проверь длину поля: ' + key);
  return value;
}
function xp(app, user) {
  const storage=require(`${__hooks}/lib/workouts_v2.js`);
  if(!storage.legacy())return storage.state(app,user).derived.xp;
  const rows = app.findRecordsByFilter('pace_progress', 'owner = {:user}', '', 1, 0, {user});
  if (!rows.length) return 0;
  const value = JSON.parse(rows[0].getString('snapshot')).xp;
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
}
function need(app, user, amount, level) {
  if (xp(app, user) < amount) throw new ForbiddenError('Нужен уровень ' + level + '. Сначала синхронизируй прогресс.');
}
function record(app, collection, id) {
  if (typeof id !== 'string' || !/^[a-z0-9]{15}$/.test(id)) throw new BadRequestError('Некорректный идентификатор');
  try { return app.findRecordById(collection, id); }
  catch (_) { throw new NotFoundError('Клуб или событие не найдено'); }
}
function member(app, user, kind, target) {
  const rows = app.findRecordsByFilter('pace_community_members','user = {:user} && kind = {:kind} && target = {:target}', '', 1, 0, {user,kind,target});
  return rows.length ? rows[0] : null;
}
function join(app, user, kind, target) {
  if (member(app,user,kind,target)) return;
  const row = new Record(app.findCollectionByNameOrId('pace_community_members'));
  row.set('user',user); row.set('kind',kind); row.set('target',target); row.set('joinedAt',new Date().toISOString()); app.save(row);
}
function info(app, user, kind, row) {
  const data = {id:row.id, name:row.getString('name'),description:row.getString('description'),city:row.getString('city'),sport:row.getString('sport'), owner:row.getString('owner') === user, joined:!!member(app,user,kind,row.id), members:app.countRecords('pace_community_members',$dbx.hashExp({kind,target:row.id}))};
  if (kind === 'event') {
    const club = record(app,'pace_clubs',row.getString('club'));
    Object.assign(data,{kind:row.getString('kind'), audience:row.getString('audience'),clubId:club.id,clubName:club.getString('name'),clubJoined:!!member(app,user,'club',club.id),startsAt:row.getString('startsAt'),endsAt:row.getString('endsAt')});
    data.scoring=require(`${__hooks}/lib/competition.js`).savedRules(row);
  }
  return data;
}
function feed(app, user, page, search = '', mine = false) {
  // Independent pages for clubs/events; no account lists, emails or workout data.
  function query(collection, kind) {
    const params = {user,search:search.toLowerCase()};
    const filters = [];
    if (search) filters.push('searchText ~ {:search}');
    if (mine) {
      const memberships = app.findRecordsByFilter('pace_community_members','user = {:user} && kind = {:kind}', '',0,0,{user,kind});
      const eligible = ['owner = {:user}'];
      memberships.forEach((row,index) => {params['m'+index] = row.getString('target');eligible.push('id = {:m'+index+'}');});
      filters.push('('+eligible.join(' || ')+')');
    }
    return app.findRecordsByFilter(collection,filters.join(' && '),'-created,-id',21,page*20,params);
  }
  const clubs = query('pace_clubs','club');
  const events = query('pace_events','event');
  const owned = app.findRecordsByFilter('pace_clubs','owner = {:user}','-created',0,0,{user});
  return {xp:xp(app,user),page,hasMore:clubs.length > 20 || events.length > 20, clubs:clubs.slice(0,20).map(r=>info(app,user,'club',r)),events:events.slice(0,20).map(r=>info(app,user,'event',r)),ownedClubs:owned.map(r=>({id:r.id,name:r.getString('name')}))};
}
module.exports = {
  read: e => e.json(200,feed(e.app,e.auth.id,0)),
  action: e => {
    const body = e.requestInfo().body;
    if(body.action==='results')return e.json(200,require(`${__hooks}/lib/competition.js`).results(e,body.id,body.page===undefined?0:body.page));
    if (body.action === 'list') {
      if (!Number.isSafeInteger(body.page) || body.page < 0 || body.page > 10000) throw new BadRequestError('Некорректная страница');
      if (body.mine !== undefined && typeof body.mine !== 'boolean') throw new BadRequestError('Некорректный фильтр');
      return e.json(200,feed(e.app,e.auth.id,body.page,text(body,'search',80),body.mine === true));
    }
    let result;
    e.app.runInTransaction(app => {
      const user = e.auth.id;
      if (body.action === 'createClub' || body.action === 'createEvent') {
        const clubMode = body.action === 'createClub';
        let club;
        if (clubMode) need(app,user,65000,10);
        else {
          club = record(app,'pace_clubs',body.clubId);
          if (club.getString('owner') !== user) throw new ForbiddenError('События создаёт только владелец клуба');
        }
        const row = new Record(app.findCollectionByNameOrId(clubMode?'pace_clubs':'pace_events'));
        row.set('owner',user);
        row.set('name',text(body,'name',80,true)); row.set('description',text(body,'description',1500,true)); row.set('city',text(body,'city',80));
        if (!sports.includes(body.sport)) throw new BadRequestError('Выбери вид спорта');
        row.set('sport',body.sport);
        row.set('searchText',[row.getString('name'),row.getString('city'),body.sport].join(' ').toLowerCase());
        if (!clubMode) {
          if (!['competition','event'].includes(body.kind) || !['open','club'].includes(body.audience) || (body.kind === 'event' && body.audience !== 'club')) throw new BadRequestError('Некорректный формат события');
          const start = Date.parse(body.startsAt), end = Date.parse(body.endsAt);
          if (typeof body.startsAt !== 'string' || typeof body.endsAt !== 'string' || !Number.isFinite(start) || !Number.isFinite(end) || start <= Date.now() || end <= start || end-start > 366*86400000) throw new BadRequestError('Начало должно быть в будущем, окончание — после начала, не более года');
          row.set('club',club.id); row.set('kind',body.kind);row.set('audience',body.audience);row.set('startsAt',new Date(start).toISOString());row.set('endsAt',new Date(end).toISOString());
          if(body.kind==='competition')row.set('scoring',require(`${__hooks}/lib/competition_engine.js`).rules(body.scoring));
        }
        app.save(row);
        if (clubMode) join(app,user,'club',row.id);
        result = info(app,user,clubMode?'club':'event',row);
      } else if (body.action === 'join' || body.action === 'leave') {
        if (!['club','event'].includes(body.targetKind)) throw new BadRequestError('Некорректная категория');
        const kind = body.targetKind;
        const row = record(app,kind==='club'?'pace_clubs':'pace_events',body.id);
        if (body.action === 'join') {
          if (kind === 'club') need(app,user,9000,5);
          else {
            if (Date.parse(row.getString('endsAt')) <= Date.now()) throw new BadRequestError('Событие уже завершилось');
            if (row.getString('audience') === 'club') {
              need(app,user,9000,5);
              if (!member(app,user,'club',row.getString('club'))) throw new ForbiddenError('Сначала вступи в клуб');
            } else need(app,user,1000,2);
          }
          join(app,user,kind,row.id);
          if(kind==='event') {const scoring=require(`${__hooks}/lib/competition.js`);scoring.sync(app,user,scoring.snapshot(app,user));}
        } else {
          if (kind === 'club' && row.getString('owner') === user) throw new BadRequestError('Владелец не может покинуть свой клуб');
          const current = member(app,user,kind,row.id); if (current) app.delete(current);
          if(kind==='event')require(`${__hooks}/lib/competition.js`).remove(app,row.id,user);
          // Leaving a club also removes membership of its club-only events.
          if (kind === 'club') {
            for (const event of app.findRecordsByFilter('pace_events','club = {:club} && audience = "club"','',0,0,{club:row.id})) {
              const entry = member(app,user,'event',event.id); if (entry) app.delete(entry);
              require(`${__hooks}/lib/competition.js`).remove(app,event.id,user);
            }
          }
        }
        result = info(app,user,kind,row);
      } else throw new BadRequestError('Неизвестное действие');
    });
    return e.json(200,result);
  }
};
