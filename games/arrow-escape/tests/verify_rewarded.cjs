const fs = require('fs'); const assert = require('assert');
const source=fs.readFileSync(require('node:path').join(__dirname,'../addons/godot_mini_game/templates/common/js/libs/sdk.js'),'utf8');
const a=source.indexOf('  showRewardedAd(callback) {');const b=source.indexOf('// ── Banner Ad',a);
const sdk=new Function('_fmtErr','return ({'+source.slice(a,b).trim()+'});')(e=>String(e.message||e));
function ad(){return {close:null,error:null,onClose(f){this.close=f},offClose(){this.close=null},onError(f){this.error=f},offError(){this.error=null},show(){return Promise.resolve()},load(){return Promise.resolve()}}}
(async()=>{
 for(const end of [true,false]){const x=ad();sdk._rewardedAd=x;const calls=[];sdk.showRewardedAd((...v)=>calls.push(v));const close=x.close;close({isEnded:end});close({isEnded:end});assert.equal(calls.length,1);assert.equal(calls[0][0],end);assert.equal(x.close,null);assert.equal(x.error,null)}
 const x=ad();sdk._rewardedAd=x;const errors=[];sdk.showRewardedAd((...v)=>errors.push(v));x.error(new Error('no fill'));await Promise.resolve();assert.equal(errors.length,1);assert.equal(errors[0][0],false);
 const retry=ad();let tries=0;retry.show=()=>++tries===1?Promise.reject(new Error('not loaded')):Promise.resolve();sdk._rewardedAd=retry;let reward=0;sdk.showRewardedAd(ok=>{if(ok)reward++});await new Promise(r=>setImmediate(r));assert.equal(tries,2);retry.close({isEnded:true});assert.equal(reward,1);
 sdk._rewardedAd=null;let missing=false;sdk.showRewardedAd((ok,error)=>{missing=!ok&&!!error});assert(missing);
 console.log('PASS: rewarded complete/cancel/error/retry/no-ad and callback deduplication');
})().catch(e=>{console.error(e);process.exit(1)});
