const C='scheda-fb-v1';
const CORE=['.','index.html','immagini.js','manifest.json','icon-192.png','icon-512.png','config.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(CORE)));self.skipWaiting();});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));});
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const u=new URL(e.request.url);
  if(u.origin!==location.origin)return; // Firestore e SDK gestiscono da soli la loro cache
  e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)));
});
