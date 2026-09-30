// Grup ve davet sayfalarını (public/) Firebase Hosting'e yayınlar: Hosting REST API ile sürüm oluştur,
// dosyaları yükle, sürümü yayına al. Kimlik: GOOGLE_APPLICATION_CREDENTIALS (hizmet hesabı).
// Kullanım: node deploy.mjs <site-adı>
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { gzipSync } from 'node:zlib';
import { GoogleAuth } from 'google-auth-library';

const site = process.argv[2];
if (!site) throw new Error('Site adı gerekli');
const root = new URL('./public/', import.meta.url).pathname;
const api = 'https://firebasehosting.googleapis.com/v1beta1';

const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.hosting', 'https://www.googleapis.com/auth/cloud-platform'],
});
const client = await auth.getClient();

async function call(method, url, body, headers = {}) {
  const res = await client.request({ method, url, data: body, headers, validateStatus: () => true });
  if (res.status >= 300) {
    console.error(`::error::${method} ${url} → ${res.status}: ${JSON.stringify(res.data)}`);
    process.exit(1);
  }
  return res.data;
}

function files(dir) {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? files(p) : [p];
  });
}

const version = await call('POST', `${api}/sites/${site}/versions`, { config: { cleanUrls: true } });
console.log('sürüm:', version.name);

const gz = new Map();
for (const f of files(root)) {
  const data = gzipSync(readFileSync(f), { level: 9 });
  const hash = createHash('sha256').update(data).digest('hex');
  gz.set('/' + relative(root, f).split('\\').join('/'), { hash, data });
}
const pop = await call('POST', `${api}/${version.name}:populateFiles`, {
  files: Object.fromEntries([...gz].map(([path, v]) => [path, v.hash])),
});
const need = new Set(pop.uploadRequiredHashes ?? []);
for (const [path, v] of gz) {
  if (!need.has(v.hash)) continue;
  await call('POST', `${pop.uploadUrl}/${v.hash}`, v.data, { 'Content-Type': 'application/octet-stream' });
  console.log('yüklendi:', path);
}
await call('PATCH', `${api}/${version.name}?update_mask=status`, { status: 'FINALIZED' });
const rel = await call('POST', `${api}/sites/${site}/releases?versionName=${encodeURIComponent(version.name)}`, {});
console.log('yayında:', rel.name, `https://${site}.web.app/grup`);
