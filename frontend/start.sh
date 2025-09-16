#!/bin/sh
set -e

PORT="${PORT:-3000}"

# Pick target: dist -> build -> public
if [ -d /app/dist ] && [ "$(ls -A /app/dist 2>/dev/null)" ]; then
  TARGET="/app/dist"
elif [ -d /app/build ] && [ "$(ls -A /app/build 2>/dev/null)" ]; then
  TARGET="/app/build"
else
  TARGET="/app/public"
fi

# Ensure target exists and has an index.html
mkdir -p "$TARGET"
if [ ! -f "$TARGET/index.html" ]; then
  if [ -f /app/public/index.html ]; then
    cp /app/public/index.html "$TARGET/index.html"
  else
    cat > "$TARGET/index.html" <<'EOF'
<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Login</title>
<style>body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial;background:#0b1022;color:#e5e7eb;display:grid;place-items:center;height:100vh}
main{max-width:720px;width:100%;padding:24px;border:1px solid #263248;border-radius:12px;background:#111827a0}
label{color:#9ca3af;font-size:14px}input{width:100%;padding:10px;border-radius:10px;border:1px solid #3b4252;background:#0b1220;color:#e5e7eb}
button{padding:10px 14px;border-radius:10px;border:1px solid #3b82f680;background:#1d4ed8;color:#fff;cursor:pointer}button+button{margin-left:8px}
.row{display:grid;grid-template-columns:1fr 1fr;gap:12px}@media(max-width:640px){.row{grid-template-columns:1fr}}</style>
</head><body><main>
<h2>Login</h2><p>Backend URL: <code id="apiText">http://localhost:8080</code></p>
<div class="row"><div><label>Username</label><input id="u" value="testuser1"></div>
<div><label>Password</label><input id="p" type="password" value="password"></div></div>
<div style="margin-top:12px"><button id="login">Login</button><button id="health">/health</button><button id="healthdb">/healthz/db</button></div>
<pre id="log" style="margin-top:12px;white-space:pre-wrap;background:#0b1220;border:1px solid #263248;border-radius:10px;padding:10px"></pre>
<script>
const api = location.origin.replace(":3000", ":8080");
document.getElementById("apiText").textContent = api;
const log = (x,p="") => { const t=new Date().toLocaleTimeString(); const s=typeof x==="string"?x:JSON.stringify(x,null,2); const el=document.getElementById("log"); el.textContent = `[${t}] ${p}${s}\n\n` + el.textContent; };
document.getElementById("health").onclick = async () => { try { const r = await fetch(`${api}/health`); log({status:r.status, data: await r.json().catch(()=>({}))}, "Health → "); } catch(e){ log({error:e.message}, "Health error → "); } };
document.getElementById("healthdb").onclick = async () => { try { const r = await fetch(`${api}/healthz/db`); log({status:r.status, data: await r.json().catch(()=>({}))}, "DB → "); } catch(e){ log({error:e.message}, "DB error → "); } };
document.getElementById("login").onclick = async () => { try {
  const u = document.getElementById("u").value.trim();
  const p = document.getElementById("p").value;
  const r = await fetch(`${api}/login`, { method:"POST", headers:{"Content-Type":"application/json"}, body: JSON.stringify({ username:u, password:p }) });
  log({status:r.status, data: await r.json().catch(()=>({}))}, r.ok ? "Login ✓ " : "Login ✗ ");
} catch(e){ log({error:e.message}, "Login error → "); } };
</script>
</main></body></html>
EOF
  fi
fi

echo "Serving $TARGET on :$PORT"
exec serve -s "$TARGET" -l "$PORT"