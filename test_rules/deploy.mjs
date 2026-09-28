// firestore.rules ve phoneHash dizinini Firebase'e uygular.
// `firebase deploy` önce Service Usage API'sini sorguladığı için Firebase Admin SDK
// hizmet hesabıyla çalışmıyor; bu betik doğrudan Firebase Rules ve Firestore Admin
// API'lerini kullanır. Kimlik: GOOGLE_APPLICATION_CREDENTIALS (hizmet hesabı JSON).
import { GoogleAuth } from 'google-auth-library';
import { readFileSync } from 'fs';

const project = process.argv[2] || 'ezansaati-premium-2026';
const rulesPath = process.argv[3] || '../firestore.rules';
const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
const client = await auth.getClient();

async function call(method, url, data) {
  try {
    const r = await client.request({ method, url, data });
    return r.data;
  } catch (e) {
    const err = e.response?.data?.error;
    const msg = err ? `${err.code} ${err.status}: ${err.message}` : e.message;
    throw Object.assign(new Error(`${method} ${url}\n  ${msg}`), { code: err?.code });
  }
}

// 1) Kural kümesi oluştur ve Firestore'a yayınla
const rules = 'https://firebaserules.googleapis.com/v1';
const ruleset = await call('POST', `${rules}/projects/${project}/rulesets`, {
  source: { files: [{ name: 'firestore.rules', content: readFileSync(rulesPath, 'utf8') }] },
});
console.log('Kural kümesi oluşturuldu:', ruleset.name);
const releaseName = `projects/${project}/releases/cloud.firestore`;
try {
  await call('PATCH', `${rules}/${releaseName}`, { release: { name: releaseName, rulesetName: ruleset.name } });
  console.log('Firestore kuralları yayınlandı (güncellendi).');
} catch (e) {
  if (e.code !== 404) throw e;
  await call('POST', `${rules}/projects/${project}/releases`, { name: releaseName, rulesetName: ruleset.name });
  console.log('Firestore kuralları yayınlandı (ilk yayın).');
}
const live = await call('GET', `${rules}/${releaseName}`);
console.log('Yayındaki kural kümesi:', live.rulesetName, live.rulesetName === ruleset.name ? '✓' : '✗');
if (live.rulesetName !== ruleset.name) process.exit(1);

// 2) Davet araması için members.phoneHash dizini (koleksiyon ve koleksiyon grubu)
const field = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/collectionGroups/members/fields/phoneHash`;
const idx = (queryScope) => ({ queryScope, fields: [{ fieldPath: 'phoneHash', order: 'ASCENDING' }] });
const op = await call('PATCH', `${field}?updateMask=indexConfig`, {
  indexConfig: { indexes: [idx('COLLECTION'), idx('COLLECTION_GROUP')] },
});
console.log('phoneHash dizini isteği gönderildi:', op.name || 'tamam');
for (let i = 0; i < 30; i++) {
  const f = await call('GET', field);
  const states = (f.indexConfig?.indexes || []).map((x) => `${x.queryScope}:${x.state}`);
  console.log('  dizin durumu:', states.join(', '));
  if (states.length && states.every((s) => s.endsWith(':READY'))) break;
  await new Promise((r) => setTimeout(r, 10000));
}
