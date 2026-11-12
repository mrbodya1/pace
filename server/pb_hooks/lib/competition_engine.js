// Pure deterministic rules. No client-submitted rank, XP or record result is used.
const metrics=['distance','duration','ascent','workouts'];
function rules(raw) {
  if (!raw || raw.version !== 1 || !metrics.includes(raw.metric)) throw new BadRequestError('Выбери формат соревнования');
  if (raw.requireHeartRate === true) throw new BadRequestError('Правила обязательного пульса ещё не согласованы');
  if(raw.requireHeartRate!==undefined && typeof raw.requireHeartRate!=='boolean')throw new BadRequestError('Проверь условие пульса');
  const result={version:1,metric:raw.metric,sex:raw.sex===undefined ? 'any' : raw.sex,requireHeartRate:false};
  if (!['any','male','female'].includes(result.sex)) throw new BadRequestError('Проверь категорию участников');
  for (const key of ['minDistanceKm','minDurationSeconds','minAscentMeters','minPaceSeconds','maxPaceSeconds']) {
    const value=raw[key] === undefined ? 0 : raw[key];
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 10000000) throw new BadRequestError('Проверь числовые условия');
    result[key]=value;
  }
  if (result.minPaceSeconds && result.maxPaceSeconds && result.minPaceSeconds > result.maxPaceSeconds) throw new BadRequestError('Границы темпа перепутаны');
  return result;
}
function utc(value) {
  return typeof value==='string' && /(Z|[+-]\d\d:\d\d)$/.test(value) ? Date.parse(value) : NaN;
}
function calculate(rule,event,joinedAt,workouts,now) {
  const r=rules(rule), start=Date.parse(event.startsAt), end=Date.parse(event.endsAt), joined=Date.parse(joinedAt);
  const excluded={};let score=0,count=0;const ids=new Set();
  const reject=reason=>{excluded[reason]=(excluded[reason]||0)+1;};
  for (const w of workouts) {
    const began=utc(w.startedAt || w.date), finished=utc(w.endedAt);
    // Workouts outside the event are irrelevant, not a personal rejection.
    if (Number.isFinite(began) && (began<start || began>=end)) continue;
    if (!Number.isFinite(began) || !Number.isFinite(finished) || finished<=began) {reject('time');continue;}
    if (!Number.isFinite(joined) || began<joined) {reject('beforeJoin');continue;}
    if (finished>end || finished>now) {reject('period');continue;}
    if (typeof w.sessionId!=='string' || !w.sessionId || ids.has(w.sessionId)) {reject('duplicate');continue;}
    ids.add(w.sessionId);
    if (event.sport!=='Все виды' && event.sport!==w.sport) {reject('sport');continue;}
    if (r.sex!=='any' && (!w.xpBreakdown || w.xpBreakdown.participantSex!==r.sex)) {reject('sex');continue;}
    if (!Number.isFinite(w.distance) || w.distance<=0 || !Number.isSafeInteger(w.durationSeconds) || w.durationSeconds<=0 || w.durationSeconds*1000>finished-began+1000) {reject('metrics');continue;}
    const ascent=w.elevationGain;
    if ((r.metric==='ascent' || r.minAscentMeters>0) && (!Number.isFinite(ascent) || ascent<0)) {reject('ascent');continue;}
    const pace=w.durationSeconds/w.distance;
    if (w.distance<r.minDistanceKm || w.durationSeconds<r.minDurationSeconds || (r.minAscentMeters>0 && ascent<r.minAscentMeters) || (r.minPaceSeconds>0 && pace<r.minPaceSeconds) || (r.maxPaceSeconds>0 && pace>r.maxPaceSeconds)) {reject('conditions');continue;}
    const value=r.metric==='distance' ? Math.round(w.distance*1000) : r.metric==='duration' ? w.durationSeconds : r.metric==='ascent' ? Math.round(ascent) : 1;
    if (!Number.isSafeInteger(value) || value<0 || !Number.isSafeInteger(score+value)) {reject('metrics');continue;}
    score+=value;count++;
  }
  return {score,workouts:count,excluded};
}
module.exports={rules,calculate};
