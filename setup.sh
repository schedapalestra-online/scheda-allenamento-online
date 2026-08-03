#!/usr/bin/env bash
# =====================================================================
#  Setup automatico - App allenamento condivisa
#  Uso:  bash setup.sh
#  Richiede: Node.js 18+ e Git installati.
# =====================================================================
set -euo pipefail
c(){ printf "\n\033[1;31m==> %s\033[0m\n" "$1"; }
ok(){ printf "\033[0;32m    OK %s\033[0m\n" "$1"; }
ask(){ read -rp "    $1: " REPLY_VAL; }

# ---------- 0. Controlli ----------
c "Controllo strumenti"
command -v node >/dev/null || { echo "Manca Node.js: installalo da nodejs.org"; exit 1; }
command -v git  >/dev/null || { echo "Manca Git: installalo da git-scm.com"; exit 1; }
ok "node $(node -v), git presente"

c "Installo Firebase CLI e GitHub CLI (se mancanti)"
command -v firebase >/dev/null || npm install -g firebase-tools
if ! command -v gh >/dev/null; then
  echo "    GitHub CLI non trovato."
  case "$(uname -s)" in
    Darwin) command -v brew >/dev/null && brew install gh || echo "    Installa 'gh' da cli.github.com" ;;
    Linux)  echo "    Installa 'gh' da cli.github.com (o: sudo apt install gh)" ;;
    *)      echo "    Installa 'gh' da cli.github.com" ;;
  esac
fi
ok "strumenti pronti"

# ---------- 1. Dati ----------
c "Dati di configurazione"
ask "Tua email (amministratore)";            EMAIL_ZIO="$REPLY_VAL"
ask "Tua password per l'app (min 6 caratteri)"; PW_ZIO="$REPLY_VAL"
ask "Email di tuo nipote";                    EMAIL_NIP="$REPLY_VAL"
ask "Password di tuo nipote (min 6 caratteri)"; PW_NIP="$REPLY_VAL"
ask "Nome progetto Firebase (minuscolo, es. scheda-famiglia-7x2)"; PROJ="$REPLY_VAL"
ask "Nome repository GitHub (es. scheda-k7x2m9)"; REPO="$REPLY_VAL"

# ---------- 2. Login ----------
c "Login Firebase (si apre il browser)"
firebase login
c "Login GitHub (si apre il browser)"
gh auth status >/dev/null 2>&1 || gh auth login

# ---------- 3. Progetto Firebase ----------
c "Creo il progetto Firebase: $PROJ"
firebase projects:create "$PROJ" --display-name "$PROJ" || echo "    (esiste gia', proseguo)"

c "Creo il database Firestore (eur3)"
firebase firestore:databases:create "(default)" --location=eur3 --project "$PROJ" \
  || echo "    (gia' presente, proseguo)"

# ---------- 4. App web + config.js ----------
c "Registro l'app web e genero config.js"
firebase apps:create WEB "scheda-web" --project "$PROJ" >/dev/null 2>&1 || true
APP_ID=$(firebase apps:list WEB --project "$PROJ" --json | node -e \
  "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const j=JSON.parse(s);console.log(j.result[0].appId)})")
firebase apps:sdkconfig WEB "$APP_ID" --project "$PROJ" --json > /tmp/sdk.json
node -e "
const fs=require('fs');
const j=JSON.parse(fs.readFileSync('/tmp/sdk.json','utf8'));
const cfg=j.result.sdkConfig||j.result;
fs.writeFileSync('config.js','export const firebaseConfig = '+JSON.stringify(cfg,null,2)+';\n');
"
ok "config.js generato"

# ---------- 5. Regole ----------
c "Pubblico le regole di sicurezza"
sed "s/EMAIL_DELLO_ZIO/$EMAIL_ZIO/g" firestore.rules > /tmp/rules.rules
cp /tmp/rules.rules firestore.rules
cat > firebase.json << 'JSON'
{ "firestore": { "rules": "firestore.rules" } }
JSON
firebase deploy --only firestore:rules --project "$PROJ"
ok "regole pubblicate"

# ---------- 6. Utenti ----------
c "Creo gli utenti"
cat > /tmp/users.js << 'JS'
const admin=require('firebase-admin');
admin.initializeApp({projectId:process.env.PROJ});
(async()=>{
 for(const [email,password] of [[process.env.E1,process.env.P1],[process.env.E2,process.env.P2]]){
   try{ await admin.auth().createUser({email,password}); console.log('    creato',email); }
   catch(e){ console.log('    ',email,'->',e.code||e.message); }
 }
})();
JS
npm install firebase-admin --silent --no-save 2>/dev/null || npm install firebase-admin --silent
PROJ="$PROJ" E1="$EMAIL_ZIO" P1="$PW_ZIO" E2="$EMAIL_NIP" P2="$PW_NIP" \
  GOOGLE_CLOUD_PROJECT="$PROJ" node /tmp/users.js || \
  echo "    Se fallisce: abilita Email/password nella console (Authentication) e rilancia."

# ---------- 7. GitHub Pages ----------
c "Pubblico i file su GitHub Pages"
git init -q 2>/dev/null || true
git add -A && git -c user.email="$EMAIL_ZIO" -c user.name="setup" commit -qm "app allenamento" || true
gh repo create "$REPO" --public --source=. --push 2>/dev/null || { git push -u origin main || true; }
USERNAME=$(gh api user -q .login)
gh api -X POST "repos/$USERNAME/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" 2>/dev/null \
  || echo "    (Pages gia' attivo o da attivare a mano in Settings > Pages)"
URL="https://$USERNAME.github.io/$REPO/"

# ---------- 8. Dominio autorizzato ----------
c "ULTIMO PASSO MANUALE"
cat << FINE

  1) Console Firebase -> Authentication -> Sign-in method
     -> abilita "Email/password"  (se non l'hai gia' fatto)
  2) Authentication -> Settings -> Authorized domains
     -> Add domain:  $USERNAME.github.io

  Poi apri:
     Dashboard (tu):   ${URL}admin.html
     App (nipote):     ${URL}index.html

  Nella dashboard fai login e premi "Pubblica la scheda" una volta.

FINE
ok "setup completato"
