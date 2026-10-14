'use strict';
(()=>{
 const cfg=window.AUDIT_CONFIG||{},status=document.getElementById('remoteStatus'),button=document.getElementById('connectRemote');
 if(!status||!button)return;
 if(!cfg.supabaseUrl||!cfg.publishableKey){status.textContent='Saved in this browser. Private server backup is not configured yet.';return}
 const base=cfg.supabaseUrl.replace(/\/$/,''),authKey='audit-supabase-session';
 if(!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(base)){status.textContent='Server configuration is invalid. Browser saving still works.';return}
 button.hidden=false;
 let session=null,revision=0,ready=false,pending=null,busy=false,timer=null;
 try{session=JSON.parse(localStorage.getItem(authKey)||'null')}catch(e){}
 async function request(path,body,token){const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{apikey:cfg.publishableKey,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});if(!r.ok)throw Error('Server request failed ('+r.status+').');return r.json()}
 async function auth(){if(session?.refresh_token){session=await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token})}else session=await request('/auth/v1/signup',{});localStorage.setItem(authKey,JSON.stringify(session));return session.access_token}
 async function flush(){if(!ready||busy||!pending)return;busy=true;const snap=pending;pending=null;status.textContent='Saved in browser · Saving private backup…';try{if(!session||session.expires_at*1000<Date.now()+60000)await auth();revision=await request('/rest/v1/rpc/audit_save',{p_packet:snap.packet_id,p_labels:snap.labels,p_position:snap.position,p_revision:revision},session.access_token);status.textContent='Saved in this browser and on the private server.'}catch(e){ready=false;pending=window.auditApp.snapshot();status.textContent='Browser copy saved. Server backup failed or another session changed it. Reconnect to check; download a backup.';button.hidden=false}finally{busy=false;if(ready&&pending)flush()}}
 window.addEventListener('audit-progress',()=>{pending=window.auditApp.snapshot();clearTimeout(timer);timer=setTimeout(flush,700)});
 async function connect(auto=false){button.disabled=true;status.textContent='Connecting to private backup…';try{
 const token=await auth();let code=auto?'':prompt('Enter your private reviewer code.');if(code===null){status.textContent='Browser autosave is active. Server backup was not connected.';return}
 const reviewer=await request('/rest/v1/rpc/audit_join',{p_code:code.trim()},token);if(reviewer!==window.auditApp.snapshot().reviewer)throw Error('wrong reviewer');
 const rows=await request('/rest/v1/audit_progress?select=packet_id,labels,task_position,revision',undefined,token);if(rows.length!==1)throw Error('Missing progress');
 const row=rows[0];if(!window.auditApp.restore(row.labels,row.task_position))throw Error('conflicting answers');revision=row.revision;ready=true;button.hidden=true;pending=window.auditApp.snapshot();await flush();
 }catch(e){ready=false;status.textContent=e.message==='wrong reviewer'?'This code belongs to the other reviewer. Use your own review link.':e.message==='conflicting answers'?'Browser and server answers differ. Neither copy was overwritten. Download this browser’s labels and resolve the difference before reconnecting.':'Private backup could not connect. Check the reviewer code and server setup. Your browser answers are preserved.'}finally{button.disabled=false}}
 button.onclick=()=>connect(false);if(session?.refresh_token)connect(true);
 window.addEventListener('online',()=>{if(ready)flush()});
})();
