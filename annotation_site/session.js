'use strict';
window.AuditSession=(()=>{
 const cfg=window.AUDIT_CONFIG,base=cfg.supabaseUrl.replace(/\/$/,''),sessionKey='audit-unique-auth',identityKey='audit-unique-identity';
 async function request(path,body,token){const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{apikey:cfg.publishableKey,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});if(!response.ok){const error=Error('Request failed ('+response.status+').');error.status=response.status;throw error}return response.json()}
 async function auth(){let session=null;try{session=JSON.parse(localStorage.getItem(sessionKey)||'null')}catch(e){}if(!session||!Number.isFinite(session.expires_at)||session.expires_at*1000<Date.now()+60000){if(session?.refresh_token){try{session=await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token})}catch(e){if(![400,401].includes(e.status))throw e;session=await request('/auth/v1/signup',{})}}else session=await request('/auth/v1/signup',{});localStorage.setItem(sessionKey,JSON.stringify(session))}return session.access_token}
 function identity(){try{const data=JSON.parse(localStorage.getItem(identityKey)||'null');return data&&typeof data.id==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(data.id)&&typeof data.code==='string'?data:null}catch(e){return null}}
 function code(){const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789',bytes=crypto.getRandomValues(new Uint8Array(20));return Array.from(bytes,n=>alphabet[n&31]).join('').match(/.{4}/g).join('-')}
 async function enter(recovery,isNew){const token=await auth();const id=await request('/rest/v1/rpc/audit_identity',{p_code:recovery,p_new:isNew},token);localStorage.setItem(identityKey,JSON.stringify({id,code:recovery}));return id}
 return {request,auth,identity,code,enter};
})();
