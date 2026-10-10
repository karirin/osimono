// Use only a dedicated loopback namespace; production SDK configuration is never changed.
const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
if (host !== "127.0.0.1:19010") throw new Error("A local community emulator is required");
fetch(`http://${host}/.settings/rules.json?ns=demo-community-swift`, {
  method: "PUT", headers: { Authorization: "Bearer owner", "Content-Type": "application/json" },
  body: JSON.stringify({ rules: { ".read": true, ".write": true } })
}).then(response => { if (!response.ok) throw new Error(`Rules setup failed: ${response.status}`); });
