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

// ================================================================ Dua grupları
console.log('Grup kurma');
const G = 'g1', CODE = 'AB4K7P';
function groupData(extra = {}) {
  return { ownerUid: 'alice', ownerName: 'Ali', name: 'Aile', code: CODE, memberUids: ['alice'],
    created: ts(now), updatedAt: ts(now), ...extra };
}
function chainData(extra = {}) {
  return { creatorUid: 'alice', creatorName: 'Ali', type: 'hatim', name: 'Hatim', unit: 'cüz', intent: '',
    total: 30, mode: 'pick', created: ts(now), deadline: ts(now + 7 * day), ...extra };
}
await t('kurucu grubu, adını ve kodunu birlikte yazar', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.set(doc(a, 'groups', G), groupData());
  b.set(doc(a, 'groups', G, 'members', 'alice'), { name: 'Ali', joinedAt: ts(now) });
  b.set(doc(a, 'groupCodes', CODE), { gid: G, name: 'Aile', ownerName: 'Ali' });
  return b.commit();
})()));
await t('başkası adına grup kurulamaz', assertFails(setDoc(doc(db('eve'), 'groups', 'g2'), groupData())));
await t('başka grubun koduna kod belgesi yazılamaz', assertFails(setDoc(doc(db('eve'), 'groupCodes', 'ZZZZZZ'), { gid: G, name: 'X', ownerName: 'E' })));
await t('üye olmayan grubu okuyamaz', assertFails(getDoc(doc(db('bob'), 'groups', G))));
await t('kodu bilen kod belgesini okur', assertSucceeds(getDoc(doc(db('bob'), 'groupCodes', CODE))));
await t('kod listesi alınamaz', assertFails(getDocs(collection(db('bob'), 'groupCodes'))));
await t('giriş yapmamış kişi kodu okuyamaz', assertFails(getDoc(doc(anon, 'groupCodes', CODE))));

console.log('Gruba katılma');
await t('bob gruba katılır (yalnız kendini ekler)', assertSucceeds((async () => {
  const d = db('bob'); const b = writeBatch(d);
  b.update(doc(d, 'groups', G), { memberUids: arrayUnion('bob'), updatedAt: ts(now) });
  b.set(doc(d, 'groups', G, 'members', 'bob'), { name: 'Veli', joinedAt: ts(now) });
  return b.commit();
})()));
await t('eve başkasını gruba ekleyemez', assertFails(updateDoc(doc(db('eve'), 'groups', G), { memberUids: arrayUnion('mallory') })));
await t('üye olmayan üye adı yazamaz', assertFails(setDoc(doc(db('eve'), 'groups', G, 'members', 'eve'), { name: 'E', joinedAt: ts(now) })));
await t('bob başkasının adını değiştiremez', assertFails(setDoc(doc(db('bob'), 'groups', G, 'members', 'alice'), { name: 'X', joinedAt: ts(now) })));
await t('üye grubu ve üyeleri okur', assertSucceeds(getDocs(collection(db('bob'), 'groups', G, 'members'))));
await t('üye gruplarını sorgular', assertSucceeds(getDocs(query(collection(db('bob'), 'groups'), where('memberUids', 'array-contains', 'bob')))));
await t('üye grubun adını değiştiremez', assertFails(updateDoc(doc(db('bob'), 'groups', G), { name: 'X' })));
await t('üye grubu silemez', assertFails(deleteDoc(doc(db('bob'), 'groups', G))));

console.log('Hatim zinciri');
await t('üye zincir başlatır', assertSucceeds(setDoc(doc(db('alice'), 'groups', G, 'chains', 'h1'), chainData())));
await t('üye olmayan zincir başlatamaz', assertFails(setDoc(doc(db('eve'), 'groups', G, 'chains', 'h2'), chainData({ creatorUid: 'eve' }))));
await t('hatim 30 cüzden farklı olamaz', assertFails(setDoc(doc(db('alice'), 'groups', G, 'chains', 'h3'), chainData({ total: 29 }))));
await t('30 günden uzun zincir olmaz', assertFails(setDoc(doc(db('alice'), 'groups', G, 'chains', 'h4'), chainData({ deadline: ts(now + 40 * day) }))));
await t('bob 7. cüzü alır', assertSucceeds(setDoc(doc(db('bob'), 'groups', G, 'chains', 'h1', 'slots', '7'), { uid: 'bob', name: 'Veli', done: false })));
await t('alınmış cüzü başkası alamaz', assertFails(setDoc(doc(db('alice'), 'groups', G, 'chains', 'h1', 'slots', '7'), { uid: 'alice', name: 'Ali', done: false })));
await t('31. cüz alınamaz', assertFails(setDoc(doc(db('bob'), 'groups', G, 'chains', 'h1', 'slots', '31'), { uid: 'bob', name: 'Veli', done: false })));
await t('başkası adına cüz alınamaz', assertFails(setDoc(doc(db('bob'), 'groups', G, 'chains', 'h1', 'slots', '8'), { uid: 'alice', name: 'Ali', done: false })));
await t('bob cüzünü okudu yapar', assertSucceeds(updateDoc(doc(db('bob'), 'groups', G, 'chains', 'h1', 'slots', '7'), { done: true })));
await t('alice bobun cüzünü işaretleyemez', assertFails(updateDoc(doc(db('alice'), 'groups', G, 'chains', 'h1', 'slots', '7'), { done: false })));
await t('başlatan eşit bölmede cüzleri üyelere dağıtır', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.set(doc(a, 'groups', G, 'chains', 'h5'), chainData({ mode: 'equal' }));
  b.set(doc(a, 'groups', G, 'chains', 'h5', 'slots', '1'), { uid: 'alice', name: 'Ali', done: false });
  b.set(doc(a, 'groups', G, 'chains', 'h5', 'slots', '16'), { uid: 'bob', name: 'Veli', done: false });
  return b.commit();
})()));
await t('grupta olmayana cüz verilemez', assertFails(setDoc(doc(db('alice'), 'groups', G, 'chains', 'h5', 'slots', '2'), { uid: 'eve', name: 'E', done: false })));
await t('üye olmayan zinciri okuyamaz', assertFails(getDocs(collection(db('eve'), 'groups', G, 'chains', 'h1', 'slots'))));

console.log('Sayılı zincir');
await t('üye salavat zinciri başlatır', assertSucceeds(setDoc(doc(db('bob'), 'groups', G, 'chains', 's1'),
  chainData({ creatorUid: 'bob', creatorName: 'Veli', type: 'salavat', name: '1000 Salavat', unit: 'salavat', total: 1000 }))));
await t('alice 300 salavat alır', assertSucceeds(setDoc(doc(db('alice'), 'groups', G, 'chains', 's1', 'claims', 'alice'), { name: 'Ali', amount: 300, done: 0 })));
await t('hedeften fazla pay alınamaz', assertFails(setDoc(doc(db('bob'), 'groups', G, 'chains', 's1', 'claims', 'bob'), { name: 'Veli', amount: 1001, done: 0 })));
await t('alice okuduğunu yazar', assertSucceeds(updateDoc(doc(db('alice'), 'groups', G, 'chains', 's1', 'claims', 'alice'), { done: 120 })));
await t('payından fazla okundu yazılamaz', assertFails(updateDoc(doc(db('alice'), 'groups', G, 'chains', 's1', 'claims', 'alice'), { done: 301 })));
await t('başkasının okuması değiştirilemez', assertFails(updateDoc(doc(db('bob'), 'groups', G, 'chains', 's1', 'claims', 'alice'), { done: 300 })));
await t('başkası adına pay alınamaz (başlatan değilse)', assertFails(setDoc(doc(db('alice'), 'groups', G, 'chains', 's1', 'claims', 'bob'), { name: 'Veli', amount: 10, done: 0 })));

console.log('Ayrılma ve silme');
await t('üye zinciri silemez (başlatan değil)', assertFails(deleteDoc(doc(db('bob'), 'groups', G, 'chains', 'h1'))));
await t('bob kendi başlattığı zinciri siler', assertSucceeds((async () => {
  const d = db('bob'); const b = writeBatch(d);
  b.delete(doc(d, 'groups', G, 'chains', 's1', 'claims', 'alice'));
  b.delete(doc(d, 'groups', G, 'chains', 's1'));
  return b.commit();
})()));
await t('bob başkasını gruptan çıkaramaz', assertFails(updateDoc(doc(db('bob'), 'groups', G), { memberUids: ['bob'] })));
await t('bob gruptan ayrılır', assertSucceeds((async () => {
  const d = db('bob'); const b = writeBatch(d);
  b.delete(doc(d, 'groups', G, 'members', 'bob'));
  b.update(doc(d, 'groups', G), { memberUids: ['alice'], updatedAt: ts(now) });
  return b.commit();
})()));
await t('ayrılan grubu okuyamaz', assertFails(getDoc(doc(db('bob'), 'groups', G))));
await t('ayrılan cüz alamaz', assertFails(setDoc(doc(db('bob'), 'groups', G, 'chains', 'h1', 'slots', '9'), { uid: 'bob', name: 'Veli', done: false })));
await t('kurucu grubu kodu ve zincirleriyle siler', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.delete(doc(a, 'groups', G, 'chains', 'h1', 'slots', '7'));
  b.delete(doc(a, 'groups', G, 'chains', 'h1'));
  b.delete(doc(a, 'groups', G, 'chains', 'h5', 'slots', '1'));
  b.delete(doc(a, 'groups', G, 'chains', 'h5', 'slots', '16'));
  b.delete(doc(a, 'groups', G, 'chains', 'h5'));
  b.delete(doc(a, 'groups', G, 'members', 'alice'));
  b.delete(doc(a, 'groupCodes', CODE));
  b.delete(doc(a, 'groups', G));
  return b.commit();
})()));

// ================================================================ bağlantılı zincirler
console.log('Bağlantılı zincir: başlatma');
const CH = 'Zc4Kq9LmP2rT7vWx1yAb', CS = 'Sd5Lr0MnQ3sU8wXy2zBc';
function linkChain(extra = {}) {
  return { creatorUid: 'alice', creatorName: 'Ali', type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, taken: 0,
    created: ts(now), deadline: ts(now + 7 * day), memberUids: ['alice'], ...extra };
}
await t('alice hatim zinciri başlatır', assertSucceeds(setDoc(doc(db('alice'), 'chains', CH), linkChain())));
await t('başkası adına zincir başlatılamaz', assertFails(setDoc(doc(db('eve'), 'chains', 'x1'), linkChain())));
await t('30 günden uzun zincir başlatılamaz', assertFails(setDoc(doc(db('alice'), 'chains', 'x2'), linkChain({ deadline: ts(now + 40 * day) }))));
await t('başka kişiler listesiyle başlatılamaz', assertFails(setDoc(doc(db('alice'), 'chains', 'x3'), linkChain({ memberUids: ['alice', 'bob'] }))));
await t('alice salavat zinciri başlatır (100)', assertSucceeds(setDoc(doc(db('alice'), 'chains', CS),
  linkChain({ type: 'salavat', name: '100 Salavat', unit: 'salavat', total: 100 }))));

console.log('Bağlantılı zincir: okuma ve katılma');
await t('bağlantıyı bilen zinciri okur', assertSucceeds(getDoc(doc(db('bob'), 'chains', CH))));
await t('giriş yapmamış kişi okuyamaz', assertFails(getDoc(doc(anon, 'chains', CH))));
await t('katılmadığı zincirleri listeleyemez', assertFails(getDocs(collection(db('eve'), 'chains'))));
await t('katıldığı zincirleri listeler', assertSucceeds(getDocs(query(collection(db('alice'), 'chains'), where('memberUids', 'array-contains', 'alice')))));
await t('bob kendini ekler', assertSucceeds(updateDoc(doc(db('bob'), 'chains', CH), { memberUids: arrayUnion('bob') })));
await t('bob başkasını ekleyemez', assertFails(updateDoc(doc(db('bob'), 'chains', CH), { memberUids: arrayUnion('eve') })));
await t('bob zincirin adını değiştiremez', assertFails(updateDoc(doc(db('bob'), 'chains', CH), { name: 'X' })));

console.log('Bağlantılı zincir: hatim');
await t('bob 5. cüzü alır', assertSucceeds(setDoc(doc(db('bob'), 'chains', CH, 'slots', '5'), { uid: 'bob', name: 'Veli', done: false })));
await t('eve katılmadan cüz alamaz', assertFails(setDoc(doc(db('eve'), 'chains', CH, 'slots', '6'), { uid: 'eve', name: 'E', done: false })));
await t('eve katılıp aynı yazmada cüz alır', assertSucceeds((async () => {
  const d = db('eve'); const b = writeBatch(d);
  b.update(doc(d, 'chains', CH), { memberUids: arrayUnion('eve') });
  b.set(doc(d, 'chains', CH, 'slots', '6'), { uid: 'eve', name: 'E', done: false });
  return b.commit();
})()));
await t('alınmış cüz başkasınca alınamaz', assertFails(setDoc(doc(db('eve'), 'chains', CH, 'slots', '5'), { uid: 'eve', name: 'E', done: false })));
await t('başkası adına cüz alınamaz', assertFails(setDoc(doc(db('bob'), 'chains', CH, 'slots', '7'), { uid: 'alice', name: 'Ali', done: false })));
await t('31. cüz yok', assertFails(setDoc(doc(db('bob'), 'chains', CH, 'slots', '31'), { uid: 'bob', name: 'Veli', done: false })));
await t('bob cüzünü okudu yapar', assertSucceeds(updateDoc(doc(db('bob'), 'chains', CH, 'slots', '5'), { done: true })));
await t('eve bob\'un cüzünü okudu yapamaz', assertFails(updateDoc(doc(db('eve'), 'chains', CH, 'slots', '5'), { done: false })));
await t('eve cüzünü bırakır', assertSucceeds(deleteDoc(doc(db('eve'), 'chains', CH, 'slots', '6'))));
await t('eve zincirden ayrılır', assertSucceeds(updateDoc(doc(db('eve'), 'chains', CH), { memberUids: ['alice', 'bob'] })));
await t('başlatan zincirden ayrılamaz', assertFails(updateDoc(doc(db('alice'), 'chains', CH), { memberUids: ['bob'] })));

console.log('Bağlantılı zincir: sayılı (hedef aşılamaz, dolunca alınamaz)');
async function take(uid, name, amount, join = true) {
  const d = db(uid); const b = writeBatch(d);
  b.set(doc(d, 'chains', CS, 'claims', uid), { name, amount, done: 0 });
  b.update(doc(d, 'chains', CS), join ? { taken: increment(amount), memberUids: arrayUnion(uid) } : { taken: increment(amount) });
  return b.commit();
}
await t('bob 60 salavat alır (katılarak)', assertSucceeds(take('bob', 'Veli', 60)));
await t('sayaç artmadan pay alınamaz', assertFails(setDoc(doc(db('eve'), 'chains', CS, 'claims', 'eve'), { name: 'E', amount: 10, done: 0 })));
await t('pay olmadan sayaç artırılamaz', assertFails(updateDoc(doc(db('eve'), 'chains', CS), { taken: increment(10), memberUids: arrayUnion('eve') })));
await t('sayaç paydan farklı artırılamaz', assertFails((async () => {
  const d = db('eve'); const b = writeBatch(d);
  b.set(doc(d, 'chains', CS, 'claims', 'eve'), { name: 'E', amount: 10, done: 0 });
  b.update(doc(d, 'chains', CS), { taken: increment(1), memberUids: arrayUnion('eve') });
  return b.commit();
})()));
await t('kalan 40\'tan fazlası alınamaz (zincir taşmaz)', assertFails(take('eve', 'E', 41)));
await t('eve kalan 40\'ı alır', assertSucceeds(take('eve', 'E', 40)));
await t('zincir doldu: yeni pay alınamaz', assertFails(take('carl', 'C', 1)));
await t('bob okuduğunu yazar', assertSucceeds(updateDoc(doc(db('bob'), 'chains', CS, 'claims', 'bob'), { done: 30 })));
await t('payından fazla okundu yazılamaz', assertFails(updateDoc(doc(db('bob'), 'chains', CS, 'claims', 'bob'), { done: 61 })));
await t('pay miktarı sonradan değiştirilemez', assertFails(updateDoc(doc(db('bob'), 'chains', CS, 'claims', 'bob'), { amount: 1 })));
await t('başkasının okuması değiştirilemez', assertFails(updateDoc(doc(db('eve'), 'chains', CS, 'claims', 'bob'), { done: 60 })));
await t('okumaya başlanan pay bırakılamaz', assertFails((async () => {
  const d = db('bob'); const b = writeBatch(d);
  b.delete(doc(d, 'chains', CS, 'claims', 'bob'));
  b.update(doc(d, 'chains', CS), { taken: increment(-60) });
  return b.commit();
})()));
await t('eve okumadığı payını bırakır (sayaç azalır)', assertSucceeds((async () => {
  const d = db('eve'); const b = writeBatch(d);
  b.delete(doc(d, 'chains', CS, 'claims', 'eve'));
  b.update(doc(d, 'chains', CS), { taken: increment(-40) });
  return b.commit();
})()));
await t('yer açılınca carl pay alır', assertSucceeds(take('carl', 'C', 40)));

console.log('Bağlantılı zincir: silme');
await t('katılan zinciri silemez', assertFails(deleteDoc(doc(db('bob'), 'chains', CS))));
await t('başlatan zinciri payları ile siler', assertSucceeds((async () => {
  const a = db('alice'); const b = writeBatch(a);
  b.delete(doc(a, 'chains', CS, 'claims', 'bob'));
  b.delete(doc(a, 'chains', CS, 'claims', 'carl'));
  b.delete(doc(a, 'chains', CS));
  b.delete(doc(a, 'chains', CH, 'slots', '5'));
  b.delete(doc(a, 'chains', CH));
  return b.commit();
})()));

await env.cleanup();
console.log(`\n${pass} geçti, ${fail} başarısız`);
process.exit(fail ? 1 : 0);
