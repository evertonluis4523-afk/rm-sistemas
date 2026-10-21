/* ===== RM · SERVICE WORKER PADRÃO =====
   Arquivo IGUAL em todos os sistemas (ver PADRAO_RM.md, "Service worker").
   Só as três linhas de configuração mudam de um sistema para outro.

   Regra única: SEMPRE A REDE, cache só sem internet.
   - Toda requisição do próprio site vai ao servidor com cache:'no-cache'
     (revalida: se nada mudou volta um 304 rápido; se mudou, vem a nova).
     Sem isso o fetch aceitava a cópia do cache HTTP -- o GitHub Pages manda
     guardar por 10 min -- e a publicação nova demorava a aparecer.
   - O cache (CACHE) guarda a última resposta boa e só é usado offline.
   - Outras origens (Firebase, CDN) passam direto, a não ser que estejam em
     ASSETS (ex.: o jsPDF da Telha, guardado para funcionar sem internet).
   Medido: com este arquivo a versão publicada aparece na próxima abertura;
   com o anterior, e sem service worker nenhum, voltava a versão velha. */
const CACHE = 'propostas-rm-v17';
const ASSETS = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './icon-maskable-512.png', './favicon.png'];
const PAGINA = './index.html';

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(ASSETS.map(a => c.add(a).catch(() => {})))));
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
const EXTERNOS = ASSETS.filter(a => /^https?:/.test(a));
const ehPagina = r => r.mode === 'navigate' || r.destination === 'document' || r.destination === 'iframe';
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const proprio = url.origin === location.origin;
  if (!proprio && !EXTERNOS.includes(req.url)) return;
  /* pela URL e não pelo pedido: pedido de navegação não aceita opções */
  const rede = proprio ? fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' }) : fetch(req);
  e.respondWith(rede.then(res => {
    if (res && res.ok && res.type !== 'opaqueredirect') {
      const cp = res.clone();
      caches.open(CACHE).then(c => c.put(proprio ? url.origin + url.pathname : req, cp)).catch(() => {});
    }
    return res;
  }).catch(() => caches.match(req, { ignoreSearch: true })
    .then(m => m || (ehPagina(req) ? caches.match(PAGINA) : undefined))
    .then(m => m || Response.error())));
});
