#!/usr/bin/env bash
# Aggiorna l'app online dopo aver modificato i file (o dopo una nuova versione).
# Uso: bash aggiorna.sh
set -euo pipefail
printf "\n\033[1;31m==> Aggiorno la versione della cache\033[0m\n"
V=$(grep -o "scheda-fb-v[0-9]*" sw.js | head -1 | grep -o "[0-9]*$")
NEW=$((V+1))
sed -i.bak "s/scheda-fb-v$V/scheda-fb-v$NEW/" sw.js && rm -f sw.js.bak
echo "    cache: v$V -> v$NEW (i telefoni scaricheranno la versione nuova)"

printf "\n\033[1;31m==> Pubblico su GitHub\033[0m\n"
git add -A
git commit -qm "aggiornamento app $(date +%Y-%m-%d)" || { echo "    Nessuna modifica da pubblicare."; exit 0; }
git push
echo "    Fatto. Online tra 1-2 minuti."
