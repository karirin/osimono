// Pure public-profile boundary, shared by the callable and offline tests.
const { createHash } = require("node:crypto");
const CATEGORIES = new Set(["gentle", "cheerful", "cool", "sweet", "fantasy", "other"]);
function key(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error("invalid-key");
  return value;
}
function text(value, max, required = false) {
  if (value != null && typeof value !== "string") throw new Error("invalid-text");
  const result = (value || "").trim();
  if ((required && !result) || result.length > max) throw new Error("invalid-length");
  return result;
}
function normalizedName(value) {
  return value.normalize("NFKC").toLowerCase().replace(/[\u30a1-\u30f6]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x60)).trim();
}
function publicID(uid, oshiID) { return createHash("sha256").update(`${uid}:${oshiID}`).digest("hex"); }
function creatorID(uid) { return createHash("sha256").update(uid).digest("hex"); }
function sanitizeDraft(data) {
  if (!data || !CATEGORIES.has(data.category) || !Array.isArray(data.tags) || data.tags.length > 5) throw new Error("invalid-profile");
  const tags = [...new Set(data.tags.map(t => text(t, 20, true)))];
  return {
    name: text(data.name, 60, true), creatorName: text(data.creatorName, 40, true),
    introduction: text(data.introduction, 240, true), category: data.category, tags,
    personality: text(data.personality, 1500), speakingStyle: text(data.speakingStyle, 1500),
    signaturePhrase: text(data.signaturePhrase, 200), sampleLine: text(data.sampleLine, 300)
  };
}
function publicProfile(record, id) {
  return { ...sanitizeDraft({ ...record, tags: record.tags || [] }), id, creatorID: creatorID(record.ownerID),
    imageUrl: record.imageUrl || null, publishedAt: record.publishedAt };
}
function ownedImagePath(imageURL, bucket, uid) {
  const url = new URL(imageURL);
  const prefix = `/v0/b/${bucket}/o/`;
  if (url.protocol !== "https:" || url.hostname !== "firebasestorage.googleapis.com" || !url.pathname.startsWith(prefix)) throw new Error("invalid-image");
  const path = decodeURIComponent(url.pathname.slice(prefix.length));
  if (!path.startsWith(`oshis/${uid}/`) && !path.startsWith(`images/${uid}/`)) throw new Error("invalid-image-owner");
  return path;
}
function catalogRulesArePrivate(configuration) {
  const rules = configuration.rules;
  if (!rules || !rules.communityOshi) return false;
  const grants = value => value != null && value !== false && value !== "false";
  function containsGrant(node) {
    if (!node || typeof node !== "object") return false;
    return grants(node[".read"]) || grants(node[".write"]) ||
      Object.entries(node).some(([key, value]) => !key.startsWith(".") && containsGrant(value));
  }
  if (grants(rules[".read"]) || grants(rules[".write"]) || containsGrant(rules.communityOshi)) return false;
  // A broad root wildcard can also authorize paths inside the catalog.
  if (Object.entries(rules).some(([key, value]) => key.startsWith("$") && containsGrant(value))) return false;
  const indexes = rules.communityOshi.profiles?.[".indexOn"] || [];
  return ["publishedAt", "searchName", "categoryName", "categoryDate"].every(field => indexes.includes(field));
}
module.exports = { catalogRulesArePrivate, CATEGORIES, key, text, normalizedName, publicID, creatorID, sanitizeDraft, publicProfile, ownedImagePath };
