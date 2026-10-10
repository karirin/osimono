// OpenAI への中継。API キーはアプリに持たせず、Secret Manager（OPENAI_API_KEY）にだけ置く。
// 設定: firebase functions:secrets:set OPENAI_API_KEY

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const openAIKey = defineSecret("OPENAI_API_KEY");

// アプリが使うモデルだけを許可する（キーを他用途に使われないように）
const ALLOWED_MODELS = new Set(["gpt-4.1-mini-2025-04-14", "gpt-4.1-nano-2025-04-14"]);
const DEFAULT_MODEL = "gpt-4.1-mini-2025-04-14";
const MAX_MESSAGES = 80;
const MAX_TOTAL_CHARS = 60000;
const DEFAULT_OUTPUT_TOKENS = 1000;
// Structured memory extraction needs room for provenance and state fields.
const MAX_OUTPUT_TOKENS = 2400;
// 1ユーザー1日あたりの呼び出し上限（返信＋記憶抽出などを含む。乱用対策で、通常利用では届かない値）
const DAILY_CALL_LIMIT = 1000;

function validateMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
    throw new HttpsError("invalid-argument", "messages が不正です");
  }
  let total = 0;
  const cleaned = messages.map((m) => {
    if (!m || typeof m.content !== "string" || !["system", "user", "assistant"].includes(m.role)) {
      throw new HttpsError("invalid-argument", "message の形式が不正です");
    }
    total += m.content.length;
    return { role: m.role, content: m.content };
  });
  if (total > MAX_TOTAL_CHARS) {
    throw new HttpsError("invalid-argument", "messages が長すぎます");
  }
  return cleaned;
}

async function consumeDailyQuota(uid) {
  const day = new Date().toISOString().slice(0, 10);
  const ref = admin.database().ref(`aiUsage/${uid}/${day}`);
  const result = await ref.transaction((count) => {
    const next = (count || 0) + 1;
    return next > DAILY_CALL_LIMIT ? undefined : next;
  });
  if (!result.committed) {
    throw new HttpsError("resource-exhausted", "本日の利用上限に達しました");
  }
}

exports.aiChat = onCall(
  {
    region: "asia-northeast1",
    secrets: [openAIKey],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です");
    }
    const data = request.data || {};
    const messages = validateMessages(data.messages);

    const model = data.model == null ? DEFAULT_MODEL : data.model;
    if (!ALLOWED_MODELS.has(model)) {
      throw new HttpsError("invalid-argument", "このモデルは使えません");
    }

    const body = { model, messages };
    if (typeof data.temperature === "number") {
      body.temperature = Math.min(Math.max(data.temperature, 0), 2);
    }
    if (data.jsonMode === true) {
      body.response_format = { type: "json_object" };
    }
    if (typeof data.cacheKey === "string" && data.cacheKey.length <= 64) {
      body.prompt_cache_key = data.cacheKey;
    }
    const maxTokens = Number.isInteger(data.maxTokens) ? data.maxTokens : DEFAULT_OUTPUT_TOKENS;
    body.max_tokens = Math.min(Math.max(maxTokens, 1), MAX_OUTPUT_TOKENS);

    await consumeDailyQuota(request.auth.uid);

    let response;
    try {
      response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openAIKey.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(50000),
      });
    } catch (error) {
      console.error("OpenAI request failed", error);
      throw new HttpsError("unavailable", "AI サーバーに接続できませんでした");
    }

    const json = await response.json().catch(() => null);
    if (!response.ok || !json) {
      // Provider error messages may contain a recognizable part of the API key.
      // Keep only the status and machine-readable code in server logs.
      console.error("OpenAI error", { status: response.status, code: json?.error?.code || null });
      if (response.status === 401) {
        throw new HttpsError("failed-precondition", "AI の接続設定に問題があります。管理者にお問い合わせください");
      }
      const code = response.status === 429 ? "resource-exhausted" : "internal";
      throw new HttpsError(code, "AI の応答でエラーが発生しました");
    }

    const content = json.choices && json.choices[0] && json.choices[0].message && json.choices[0].message.content;
    if (typeof content !== "string") {
      throw new HttpsError("internal", "AI の応答が不正です");
    }
    return { content };
  }
);

// Community discovery uses a separate, explicitly published profile boundary.
Object.assign(exports, require("./community-oshi"));
