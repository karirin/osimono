const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onValueDeleted } = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
const { randomUUID } = require("node:crypto");
const profile = require("./community-profile");
const PAGE_SIZE = 30;

// All community nodes are server-only. Do not expose the private /oshis tree to discovery.
function root() { return admin.database().ref("communityOshi"); }
async function quota(uid, action, maximum) {
  const day = new Date().toISOString().slice(0, 10);
  const result = await root().child(`usage/${uid}/${day}/${action}`).transaction(value =>
    (value || 0) >= maximum ? undefined : (value || 0) + 1);
  if (!result.committed) throw new HttpsError("resource-exhausted", "本日の利用上限に達しました。時間をおいて再試行してください。");
}
async function visibleRecord(uid, id) {
  const [snapshot, hidden] = await Promise.all([
    root().child(`profiles/${id}`).get(), root().child(`hidden/${uid}/${id}`).get()
  ]);
  const record = snapshot.val();
  if (!record || hidden.exists() || record.disabled === true) throw new HttpsError("not-found", "この推しは公開を終了したか、表示できなくなりました。");
  const source = await admin.database().ref(`oshis/${record.ownerID}/${record.sourceOshiID}`).get();
  if (!source.exists()) throw new HttpsError("not-found", "この推しは公開を終了しました。");
  return record;
}
async function copyPublicImage(imageURL, uid, id) {
  if (!imageURL) return null;
  const bucket = admin.storage().bucket();
  let source;
  try { source = profile.ownedImagePath(imageURL, bucket.name, uid); }
  catch { throw new HttpsError("failed-precondition", "この画像は公開できません。自分の画像を設定するか、画像の公開をオフにしてください。"); }
  const file = bucket.file(source);
  const [metadata] = await file.getMetadata();
  if (!/^image\/(jpeg|png|webp)$/.test(metadata.contentType || "") || Number(metadata.size) > 10 * 1024 * 1024) {
    throw new HttpsError("failed-precondition", "公開する画像は10MB以下のJPEG・PNG・WebPにしてください。");
  }
  // Immutable copy: later private image edits/deletion must not change another user's registered character.
  const token = randomUUID();
  const destination = `communityOshiAssets/${id}/${token}`;
  await file.copy(bucket.file(destination), {
    contentType: metadata.contentType, metadata: { firebaseStorageDownloadTokens: token }
  });
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media&token=${token}`;
}

exports.communityOshi = onCall({ region: "asia-northeast1", timeoutSeconds: 60, memory: "256MiB" }, async request => {
  if (!request.auth) throw new HttpsError("unauthenticated", "ログインが必要です。");
  const uid = request.auth.uid;
  const data = request.data || {};
  try {
    // Fail closed if deployed before the legacy global read/write rules have been migrated.
    // Check the effective ancestors too: a child-level false cannot revoke a root grant.
    const rules = await admin.database().getRulesJSON();
    if (!profile.catalogRulesArePrivate(rules)) {
      throw new HttpsError("failed-precondition", "みんなの推しは準備中です。公開用のデータ保護設定が完了するまでお待ちください。");
    }
    switch (data.action) {
    case "list": {
      const search = profile.normalizedName(profile.text(data.search, 60));
      const category = data.category || "";
      if (category && !profile.CATEGORIES.has(category)) throw new Error("invalid-category");
      const field = search ? (category ? "categoryName" : "searchName") : (category ? "categoryDate" : "publishedAt");
      const prefix = category ? `${category}:` : "";
      let lower = search ? prefix + search : category ? prefix : null;
      let upper = search ? prefix + search + "\uf8ff" : category ? prefix + "\uf8ff" : null;
      let lowerKey, upperKey;
      if (data.cursor) {
        profile.key(data.cursor.id);
        const value = data.cursor.value;
        if (field === "publishedAt" ? !Number.isFinite(value) : typeof value !== "string" || value.length > 150) throw new Error("invalid-cursor");
        if (search) {
          if (!value.startsWith(prefix + search)) throw new Error("invalid-cursor");
          lower = value; lowerKey = data.cursor.id;
        } else {
          if (category && !value.startsWith(prefix)) throw new Error("invalid-cursor");
          upper = value; upperKey = data.cursor.id;
        }
      }
      let query = root().child("profiles").orderByChild(field);
      if (lower != null) query = lowerKey ? query.startAt(lower, lowerKey) : query.startAt(lower);
      if (upper != null) query = upperKey ? query.endAt(upper, upperKey) : query.endAt(upper);
      const [snapshot, hiddenSnapshot] = await Promise.all([
        (search ? query.limitToFirst(PAGE_SIZE + 2) : query.limitToLast(PAGE_SIZE + 2)).get(),
        root().child(`hidden/${uid}`).get()
      ]);
      let rows = [];
      snapshot.forEach(child => { rows.push({ id: child.key, record: child.val() }); });
      if (!search) rows.reverse();
      rows = rows.filter(row => row.id !== data.cursor?.id);
      const hasMore = rows.length > PAGE_SIZE;
      rows = rows.slice(0, PAGE_SIZE);
      const hidden = hiddenSnapshot.val() || {};
      const last = rows.at(-1);
      return {
        profiles: rows.filter(row => !hidden[row.id] && !row.record.disabled && row.record.ownerID !== uid).map(row => profile.publicProfile(row.record, row.id)),
        cursor: hasMore && last ? { id: last.id, value: last.record[field] } : null
      };
    }
    case "detail": return { profile: profile.publicProfile(await visibleRecord(uid, profile.key(data.id)), data.id) };
    case "mine": {
      const oshiID = profile.key(data.oshiID);
      const [source, published] = await Promise.all([
        admin.database().ref(`oshis/${uid}/${oshiID}`).get(), root().child(`profiles/${profile.publicID(uid, oshiID)}`).get()
      ]);
      if (!source.exists()) throw new HttpsError("not-found", "推しが見つかりません。");
      const own = source.val();
      const current = published.val();
      return {
        published: !!current, disabled: current?.disabled === true,
        importedCreator: own.communitySourceID ? (own.communityCreatorName || "Creator") : null,
        imageUrl: own.imageUrl || null,
        draft: current ? profile.publicProfile(current, published.key) : {
          name: own.name || "", personality: own.personality || "", speakingStyle: own.speaking_style || "", signaturePhrase: own.signature_phrase || ""
        }
      };
    }
    case "publish": {
      const oshiID = profile.key(data.oshiID);
      if (data.consent !== true) throw new HttpsError("failed-precondition", "公開内容を確認してください。");
      const draft = profile.sanitizeDraft(data.draft);
      const source = await admin.database().ref(`oshis/${uid}/${oshiID}`).get();
      if (!source.exists() || source.val().communitySourceID) throw new HttpsError("permission-denied", "自分で作成した推しだけを公開できます。");
      await quota(uid, "publish", 20);
      const id = profile.publicID(uid, oshiID);
      const ref = root().child(`profiles/${id}`);
      const existing = (await ref.get()).val();
      if (existing?.disabled || (await root().child(`disabled/${id}`).get()).exists()) throw new HttpsError("permission-denied", "この推しの公開は停止されています。");
      const imageUrl = data.draft.includeImage === true ? await copyPublicImage(source.val().imageUrl, uid, id) : null;
      const now = Date.now();
      const publishedAt = existing?.publishedAt || now;
      const searchName = profile.normalizedName(draft.name);
      const record = { ...draft, ownerID: uid, sourceOshiID: oshiID, publishedAt, updatedAt: now,
        searchName, categoryName: `${draft.category}:${searchName}`, categoryDate: `${draft.category}:${publishedAt}`, imageUrl };
      await ref.set(record);
      // A deletion/moderation action may have completed while the image copy was in progress.
      const [stillExists, disabled] = await Promise.all([
        admin.database().ref(`oshis/${uid}/${oshiID}`).get(), root().child(`disabled/${id}`).get()
      ]);
      if (!stillExists.exists() || disabled.exists()) {
        await ref.remove();
        throw new HttpsError("failed-precondition", "この推しは公開できなくなりました。");
      }
      return { profile: profile.publicProfile(record, id) };
    }
    case "unpublish": {
      const id = profile.publicID(uid, profile.key(data.oshiID));
      await root().child(`profiles/${id}`).remove();
      return { ok: true };
    }
    case "report": {
      const id = profile.key(data.id);
      const reasons = new Set(["inappropriate", "rights", "privacy", "other"]);
      if (!reasons.has(data.reason)) throw new Error("invalid-reason");
      const record = await visibleRecord(uid, id);
      await quota(uid, "report", 20);
      await root().update({
        [`reports/${id}/${uid}`]: { reason: data.reason, createdAt: Date.now(), profile: record },
        [`hidden/${uid}/${id}`]: true
      });
      return { ok: true };
    }
    case "hide": {
      const id = profile.key(data.id);
      await root().child(`hidden/${uid}/${id}`).set(true);
      return { ok: true };
    }
    default: throw new Error("invalid-action");
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error.message?.startsWith("invalid-")) throw new HttpsError("invalid-argument", "入力内容や文字数を確認してください。");
    console.error("communityOshi failed", { action: data.action, code: error.code || "unknown" });
    throw new HttpsError("unavailable", "読み込みまたは保存に失敗しました。時間をおいて再試行してください。");
  }
});

// Covers every existing delete entry point, including older app versions.
exports.unpublishDeletedOshi = onValueDeleted({ ref: "/oshis/{uid}/{oshiID}", region: "us-central1", instance: "osimono-default-rtdb" }, async event => {
  await root().child(`profiles/${profile.publicID(event.params.uid, event.params.oshiID)}`).remove();
});
