import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, collection, collectionGroup, query, where,
         getDocs, Timestamp, arrayUnion, increment } from 'firebase/firestore';
import { readFileSync } from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'ezansaati-premium-2026',
  firestore: { rules: readFileSync(process.argv[2], 'utf8'), host: '127.0.0.1', port: 8080 },
});
const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = env.unauthenticatedContext().firestore();
const H = 'a'.repeat(64), H2 = 'b'.repeat(64);
const now = Date.now(), day = 86400000;
const ts = (ms) => Timestamp.fromMillis(ms);
let pass = 0, fail = 0;
async function t(name, p) {
  try { await p; pass++; console.log('  ✓', name); } catch (e) { fail++; console.log('  ✗', name, '\n    ', e.message); }
}
const denorm = { circleName: '110 Salavat', ownerName: 'Ali', ownerUid: 'alice', type: 'salavat', intent: '',
  total: 110, endDate: '2026-10-05', deadline: ts(now + 7 * day) };
function circleData(extra = {}) {
  return { ownerUid: 'alice', ownerName: 'Ali', type: 'salavat', name: '110 Salavat', intent: '', total: 110,
    created: ts(now), endDate: '2026-10-05', deadline: ts(now + 7 * day), memberUids: ['alice'], lastJoin: '',
    notice: '', ...extra };
}
function invite(extra = {}) {
  return { name: 'Veli', share: 55, done: 0, status: 'pending', uid: null, phoneHash: H,
    invitedAt: ts(now), expiresAt: ts(now + day), respondedAt: null, ...denorm, ...extra };
}
async function createCircle(cid, members) {
  const a = db('alice');
  const b = writeBatch(a);
  b.set(doc(a, 'circles', cid), circleData());
  b.set(doc(a, 'circles', cid, 'members', 'alice'), { name: 'Ali', share: 55, done: 0, status: 'owner', uid: 'alice',
    phoneHash: null, invitedAt: ts(now), expiresAt: null, respondedAt: null, ...denorm });
  for (const [code, data] of Object.entries(members)) {
    b.set(doc(a, 'circles', cid, 'members', code), data);
    b.set(doc(a, 'invites', code), { circleId: cid, createdAt: ts(now) });
  }
  return b.commit();
}
async function acceptAs(uid, cid, code) {
  const d = db(uid);
  const b = writeBatch(d);
  b.update(doc(d, 'circles', cid, 'members', code), { status: 'accepted', uid, phoneHash: null, respondedAt: ts(now) });
  b.update(doc(d, 'circles', cid), { memberUids: arrayUnion(uid), lastJoin: code });
  return b.commit();
}

await env.clearFirestore();
console.log('Kullanıcı profili');
await t('kendi profilini yazar', assertSucceeds(setDoc(doc(db('bob'), 'users', 'bob'), { name: 'Veli', phoneHash: H, updatedAt: ts(now) })));
await t('başkasının profilini okuyamaz', assertFails(getDoc(doc(db('eve'), 'users', 'bob'))));
await t('profilde açık numara alanı yazılamaz', assertFails(setDoc(doc(db('eve'), 'users', 'eve'), { name: 'E', phone: '0532', phoneHash: null })));
await t('giriş yapmamış kişi hiçbir şey okuyamaz', assertFails(getDoc(doc(anon, 'invites', 'CODE000001'))));

console.log('Çember kurma');
await t('kurucu çemberi, üyeleri ve davet kodunu birlikte yazar', assertSucceeds(createCircle('c1', { CODEBOB001: invite(), CODECAR001: invite({ name: 'Ayşe', phoneHash: null }) })));
await t('30 günden uzun çember kurulamaz', assertFails(setDoc(doc(db('alice'), 'circles', 'c2'), circleData({ deadline: ts(now + 40 * day) }))));
await t('başkası adına çember kurulamaz', assertFails(setDoc(doc(db('eve'), 'circles', 'c3'), circleData())));

console.log('Gizlilik');
await t('yabancı çemberi okuyamaz', assertFails(getDoc(doc(db('eve'), 'circles', 'c1'))));
await t('yabancı üyeleri listeleyemez', assertFails(getDocs(collection(db('eve'), 'circles', 'c1', 'members'))));
await t('davet kodları listelenemez', assertFails(getDocs(collection(db('eve'), 'invites'))));
await t('kodu bilen daveti görür', assertSucceeds(getDoc(doc(db('bob'), 'invites', 'CODEBOB001'))));
await t('kodu bilen bekleyen davet belgesini okur', assertSucceeds(getDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'))));
await t('kurucunun üye belgesini yabancı okuyamaz', assertFails(getDoc(doc(db('eve'), 'circles', 'c1', 'members', 'alice'))));
await t('numara özeti eşleşen kişi davetlerini listeler',
  assertSucceeds(getDocs(query(collectionGroup(db('bob'), 'members'), where('phoneHash', '==', H)))));
await setDoc(doc(db('eve'), 'users', 'eve'), { name: 'E', phoneHash: H2, updatedAt: ts(now) });
await t('başkasının numara özetiyle davet listelenemez',
  assertFails(getDocs(query(collectionGroup(db('eve'), 'members'), where('phoneHash', '==', H)))));
await t('filtresiz davet taraması yapılamaz', assertFails(getDocs(collectionGroup(db('eve'), 'members'))));

console.log('Davet kabul / ret');
await t('eve kabul etmediği çembere kendini ekleyemez',
  assertFails(updateDoc(doc(db('eve'), 'circles', 'c1'), { memberUids: arrayUnion('eve'), lastJoin: 'CODEBOB001' })));
await t('davetli kabul ederken payını değiştiremez',
  assertFails(updateDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'), { status: 'accepted', uid: 'bob', phoneHash: null, share: 1 })));
await t('bob daveti kabul eder ve üye olur', assertSucceeds(acceptAs('bob', 'c1', 'CODEBOB001')));
await t('kabul edilmiş davet başkası tarafından alınamaz', assertFails(acceptAs('eve', 'c1', 'CODEBOB001')));
await t('bob artık çemberi okur', assertSucceeds(getDoc(doc(db('bob'), 'circles', 'c1'))));
await t('bob üyeleri görür', assertSucceeds(getDocs(collection(db('bob'), 'circles', 'c1', 'members'))));
await t('kabulden sonra numara özeti silinmiş', (async () => {
  const s = await getDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'));
  if (s.data().phoneHash !== null) throw new Error('phoneHash duruyor');
})());
await t('ayşe (kodla) daveti reddeder', assertSucceeds(updateDoc(doc(db('carol'), 'circles', 'c1', 'members', 'CODECAR001'), { status: 'declined', respondedAt: ts(now) })));
await t('reddeden kişi durumu yeniden değiştiremez', assertFails(updateDoc(doc(db('carol'), 'circles', 'c1', 'members', 'CODECAR001'), { status: 'pending' })));

console.log('24 saat kuralı');
await createCircle('c4', { CODEOLD001: invite({ invitedAt: ts(now - 2 * day), expiresAt: ts(now - day) }) });
await t('süresi geçmiş davet kabul edilemez', assertFails(acceptAs('bob', 'c4', 'CODEOLD001')));

console.log('Okuma ilerlemesi');
await t('bob kendi okumasını günceller', assertSucceeds(updateDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'), { done: 10 })));
await t('bob payından fazla yazamaz', assertFails(updateDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'), { done: 56 })));
await t('bob kendi payını değiştiremez', assertFails(updateDoc(doc(db('bob'), 'circles', 'c1', 'members', 'CODEBOB001'), { share: 100 })));
await t('bob kurucunun okumasını değiştiremez', assertFails(updateDoc(doc(db('bob'), 'circles', 'c1', 'members', 'alice'), { done: 55 })));
await t('kurucu kendi okumasını günceller', assertSucceeds(updateDoc(doc(db('alice'), 'circles', 'c1', 'members', 'alice'), { done: 55 })));
await t('kurucu reddedenin payını kendine alır', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.delete(doc(a, 'circles', 'c1', 'members', 'CODECAR001'));
  b.delete(doc(a, 'invites', 'CODECAR001'));
  b.update(doc(a, 'circles', 'c1', 'members', 'alice'), { share: increment(55) });
  b.update(doc(a, 'circles', 'c1'), { notice: 'Ayşe daveti kabul etmedi.' });
  return b.commit();
})()));

console.log('Çember yönetimi');
await t('üye çemberin adını değiştiremez', assertFails(updateDoc(doc(db('bob'), 'circles', 'c1'), { name: 'X' })));
await t('kurucu çemberi düzenler', assertSucceeds(updateDoc(doc(db('alice'), 'circles', 'c1'), { name: '110 Salavat (şifa)' })));
await t('kurucu son günü 30 günden öteye taşıyamaz', assertFails(updateDoc(doc(db('alice'), 'circles', 'c1'), { deadline: ts(now + 45 * day) })));
await t('üye çemberi silemez', assertFails(deleteDoc(doc(db('bob'), 'circles', 'c1'))));
await t('kurucu çemberi tüm üyeleriyle siler', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.delete(doc(a, 'circles', 'c1', 'members', 'alice'));
  b.delete(doc(a, 'circles', 'c1', 'members', 'CODEBOB001'));
  b.delete(doc(a, 'invites', 'CODEBOB001'));
  b.delete(doc(a, 'circles', 'c1'));
  return b.commit();
})()));

await env.cleanup();
console.log(`\n${pass} geçti, ${fail} başarısız`);
process.exit(fail ? 1 : 0);
