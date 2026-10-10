const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const enabled = !!process.env.FIREBASE_DATABASE_EMULATOR_HOST;
if (enabled && process.env.FIREBASE_DATABASE_EMULATOR_HOST !== "127.0.0.1:19010") throw new Error("Local emulator required");
const emulatorCredential = enabled ? admin.credential.applicationDefault() : null;
if (enabled) emulatorCredential.getAccessToken = async () => ({ access_token: "owner", expires_in: 3600 });
if (enabled) admin.initializeApp({ credential: emulatorCredential, projectId: "demo-community", databaseURL: "https://demo-community-default-rtdb.firebaseio.com", storageBucket: "demo-community.appspot.com" });
const api = enabled ? require("../community-oshi") : null;
const p = require("../community-profile");
const call = (uid, action, data = {}) => api.communityOshi.run({ auth: uid ? { uid } : null, data: { action, ...data } });
const draft = { name: "リン", creatorName: "そら", introduction: "聞き上手", category: "gentle", tags: ["雑談"], personality: "優しい", speakingStyle: "丁寧", signaturePhrase: "", sampleLine: "おかえり", includeImage: false };

test("community callable with actual database: authorization, pagination, privacy, lifecycle and reports", { skip: !enabled }, async t => {
  let rules;
  t.after(async () => {
    if (rules) await rules.cleanup();
    if (admin.apps.length) await admin.app().delete();
  });
  await admin.database().ref().set(null);
  await assert.rejects(call(null, "list"), { code: "unauthenticated" });
  await admin.database().ref("oshis/creator/private").set({ name: "リン", memo: "SECRET", shared_memory: "SECRET", relationship_detail: "SECRET" });
  await assert.rejects(call("viewer", "publish", { oshiID: "private", consent: true, draft }), { code: "permission-denied" });
  await assert.rejects(call("creator", "publish", { oshiID: "private", consent: false, draft }), { code: "failed-precondition" });
  const published = (await call("creator", "publish", { oshiID: "private", consent: true, draft: { ...draft, shared_memory: "SECRET" } })).profile;
  assert.ok(!JSON.stringify(published).includes("SECRET"));
  const id = published.id;
  assert.equal((await call("viewer", "list", { search: "り", category: "gentle" })).profiles[0].id, id);
  assert.equal((await call("creator", "list")).profiles.length, 0);
  assert.equal((await call("viewer", "list", { category: "cool" })).profiles.length, 0);
  assert.equal((await call("viewer", "detail", { id })).profile.name, "リン");
  await call("viewer", "unpublish", { oshiID: "private" });
  assert.equal((await call("viewer", "detail", { id })).profile.id, id, "another owner cannot unpublish it");
  await admin.database().ref("oshis/viewer/copied").set({ name: "copy", communitySourceID: id, communityCreatorName: "そら" });
  await assert.rejects(call("viewer", "publish", { oshiID: "copied", consent: true, draft }), { code: "permission-denied" });
  await call("viewer", "report", { id, reason: "privacy" });
  assert.equal((await call("viewer", "list")).profiles.length, 0);
  await assert.rejects(call("viewer", "detail", { id }), { code: "not-found" });
  assert.equal((await admin.database().ref(`communityOshi/reports/${id}/viewer`).get()).val().reason, "privacy");
  await call("creator", "unpublish", { oshiID: "private" });
  await assert.rejects(call("another", "detail", { id }), { code: "not-found" });
  assert.equal((await admin.database().ref("oshis/viewer/copied").get()).val().name, "copy");
  if (process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    await t.test("published avatars remain downloadable after source deletion and unpublishing", async () => {
    const bucket = admin.storage().bucket();
    const sourcePath = "oshis/creator/private/avatar.jpg";
    await bucket.file(sourcePath).save(Buffer.from("original-avatar"), { metadata: { contentType: "image/jpeg" } });
    const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(sourcePath)}?alt=media`;
    await admin.database().ref("oshis/creator/private/imageUrl").set(imageUrl);
    const withImage = (await call("creator", "publish", { oshiID: "private", consent: true, draft: { ...draft, includeImage: true } })).profile;
    const publicURL = new URL(withImage.imageUrl);
    const copiedPath = decodeURIComponent(publicURL.pathname.split("/o/")[1]);
    assert.ok(copiedPath.startsWith(`communityOshiAssets/${id}/`));
    const [metadata] = await bucket.file(copiedPath).getMetadata();
    assert.equal(metadata.metadata.firebaseStorageDownloadTokens, publicURL.searchParams.get("token"));
    assert.equal(metadata.contentType, "image/jpeg");
    await bucket.file(sourcePath).delete();
    await call("creator", "unpublish", { oshiID: "private" });
    const [bytes] = await bucket.file(copiedPath).download();
    assert.equal(bytes.toString(), "original-avatar", "source deletion and unpublishing preserve registered images");
    const download = await fetch(`http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}${publicURL.pathname}${publicURL.search}`);
    assert.equal(download.status, 200, "the returned token actually downloads the public copy");
    await bucket.file(copiedPath).delete();
    });
  }
  const records = {};
  for (let i = 0; i < 65; i++) {
    const key = `entry${String(i).padStart(3, "0")}`;
    records[key] = { ...draft, ownerID: "creator", sourceOshiID: "private", publishedAt: 1000 + i,
      searchName: "りん", categoryName: "gentle:りん", categoryDate: `gentle:${1000 + i}` };
  }
  await admin.database().ref("communityOshi/profiles").set(records);
  for (const filters of [{}, { search: "リン" }, { category: "gentle" }, { search: "り", category: "gentle" }]) {
    let ids = [], cursor = null;
    do {
      const page = await call("another", "list", { ...filters, cursor });
      ids.push(...page.profiles.map(x => x.id)); cursor = page.cursor;
    } while (cursor);
    assert.equal(ids.length, 65); assert.equal(new Set(ids).size, 65);
  }
  await admin.database().ref(`communityOshi/profiles/${p.publicID("creator", "private")}`).set(records.entry000);
  await api.unpublishDeletedOshi.run({ params: { uid: "creator", oshiID: "private" } });
  assert.equal((await admin.database().ref(`communityOshi/profiles/${p.publicID("creator", "private")}`).get()).exists(), false);
  const endpoint = `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}/communityOshi/profiles.json?ns=demo-community-default-rtdb`;
  assert.equal((await fetch(endpoint)).status, 401, "direct public reads must be denied");
  assert.equal((await fetch(endpoint, { method: "PUT", body: JSON.stringify({ forged: true }) })).status, 401, "direct public writes must be denied");
  rules = await initializeTestEnvironment({ projectId: "demo-community", database: {
    host: "127.0.0.1", port: 19010,
    rules: require("node:fs").readFileSync(require("node:path").join(__dirname, "database.rules.json"), "utf8")
  }});
  const viewerDB = rules.authenticatedContext("viewer").database();
  await assertFails(viewerDB.ref("communityOshi/profiles").once("value"));
  await assertFails(viewerDB.ref("communityOshi/reports").once("value"));
  await assertFails(viewerDB.ref("communityOshi/profiles/forged").set({ ownerID: "viewer" }));
  await assertFails(viewerDB.ref("oshis/creator").once("value"));
  await assertFails(viewerDB.ref("oshis/creator/private").set({ name: "forged" }));
  await assertSucceeds(viewerDB.ref("oshis/viewer/new").set({ name: "own" }));
  await assertSucceeds(viewerDB.ref("oshis/viewer").once("value"));
  await assertSucceeds(viewerDB.ref("users/viewer/selectedOshiId").set("new"));
  try {
    await admin.database().setRules({ rules: { ".read": true, ".write": true } });
    await assert.rejects(call("creator", "publish", { oshiID: "private", consent: true, draft }), { code: "failed-precondition" });
  } finally {
    await admin.database().setRules(require("./database.rules.json"));
  }
});
