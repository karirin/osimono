const test = require("node:test");
const assert = require("node:assert/strict");
const p = require("../community-profile");
const draft = { name: " 凛 ", creatorName: "そら", introduction: "落ち着いた聞き上手", category: "gentle", tags: ["雑談"], personality: "優しい", speakingStyle: "短い敬語", signaturePhrase: "", sampleLine: "おかえり。" };
test("public profile strips private fields and does not expose owner IDs", () => {
  const record = { ...draft, ownerID: "private-user", sourceOshiID: "private-oshi", memo: "secret", user_nickname: "secret", shared_memory: "secret", relationship_detail: "secret", messages: ["secret"], publishedAt: 5 };
  const result = p.publicProfile(record, "public-id");
  assert.equal(result.name, "凛");
  assert.equal(result.creatorID, p.creatorID("private-user"));
  assert.ok(!JSON.stringify(result).includes("secret"));
  assert.ok(!JSON.stringify(result).includes("private-user"));
  assert.ok(!Object.hasOwn(result, "sourceOshiID"));
});
test("validation rejects malformed, oversized and unknown category input", () => {
  for (const change of [{ name: " " }, { name: "a".repeat(61) }, { category: "invalid" }, { tags: Array(6).fill("a") }, { tags: ["a".repeat(21)] }, { personality: {} }]) {
    assert.throws(() => p.sanitizeDraft({ ...draft, ...change }));
  }
  for (const id of ["../user", "a.b", "a/b", "", undefined]) assert.throws(() => p.key(id));
});
test("Japanese kana, case and full width names normalize for prefix search", () => {
  assert.equal(p.normalizedName("　ＲＩＮ カナ　"), "rin かな");
});
test("public identity is stable and distinct across owners", () => {
  assert.equal(p.publicID("u1", "c"), p.publicID("u1", "c"));
  assert.notEqual(p.publicID("u1", "c"), p.publicID("u2", "c"));
});
test("image sharing only accepts this owner's Firebase storage objects", () => {
  const url = path => `https://firebasestorage.googleapis.com/v0/b/demo/o/${encodeURIComponent(path)}?alt=media`;
  assert.equal(p.ownedImagePath(url("oshis/u1/c/avatar.jpg"), "demo", "u1"), "oshis/u1/c/avatar.jpg");
  for (const value of [url("oshis/u2/c/avatar.jpg"), url("oshis/u11/a.jpg"), "https://example.com/a.jpg", "http://localhost/private", url("communityOshiAssets/a")]) {
    assert.throws(() => p.ownedImagePath(value, "demo", "u1"));
  }
});

test("catalog refuses inherited public grants, wildcard grants and missing indexes", () => {
  const safe = require("./database.rules.json");
  assert.equal(p.catalogRulesArePrivate(safe), true);
  assert.equal(p.catalogRulesArePrivate({ rules: { ...safe.rules, ".read": "true" } }), false);
  assert.equal(p.catalogRulesArePrivate({ rules: { ...safe.rules, ".write": "auth != null" } }), false);
  assert.equal(p.catalogRulesArePrivate({ rules: { ...safe.rules, "$any": { ".write": true } } }), false);
  assert.equal(p.catalogRulesArePrivate({ rules: { ...safe.rules, communityOshi: { profiles: { ".read": true } } } }), false);
  assert.equal(p.catalogRulesArePrivate({ rules: { ".read": false, ".write": false } }), false);
});
