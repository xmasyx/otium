#!/bin/bash
# Costruisce Otium.app e la installa.
#
# È un involucro: il lavoro sta in Arche, in un solo script parametrico condiviso da tutte le app
# della famiglia. Le cose che valgono SOLO per Otium restano qui e in `arche-hooks.sh`:
#
#   - il prodotto SwiftPM si chiama `OtiumApp`, l'app si chiama `Otium`;
#   - ogni taglia dell'icona si DISEGNA, non si riduce: la frase «otium cum dignitate» sotto i
#     256 px non è leggibile, e ridurre la 1024 la ridurrebbe a una riga sporca;
#   - il parcheggio: se l'installata è viva, il bundle nuovo prende un nome che non finisce in
#     `.app`, così non ci sono due Otium apribili nella finestra in cui il danno è massimo;
#   - la copia di staging in `dist/` si cancella dopo l'installazione (aggancio post-install).
#
# L'interfaccia di prima è intatta, perché la usa la CI:
#   Scripts/build-app.sh [cartella-destinazione]
#   OTIUM_VERSION=1.2.0   OTIUM_SKIP_INSTALL=1
#
# Ritorno indietro: `git checkout pre-arche-20260826 -- Scripts/build-app.sh`
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHE="${ARCHE_TOOLS:-$HOME/.claude/skills/Arche/Tools}"
DEST="${1:-$ROOT/dist}"

ARGS=(
    --root "$ROOT"
    --nome Otium
    --prodotto OtiumApp
    --dest "$DEST"
    --icona disegnata
    --icona-strumento "$ROOT/Scripts/MakeIcon.swift"
    --icona-nome Otium
    --lsui true
    --min-os 15.0
    --copyright "Locale. Nessuna rete, nessun permesso di sistema."
    --parcheggio
    --version "${OTIUM_VERSION:-1.1.0}"
)

if [[ "${OTIUM_SKIP_INSTALL:-0}" == "1" ]]; then
    ARGS+=(--no-install)
fi

# La cartella di staging si cancella solo quando è la NOSTRA: `build-app.sh <cartella>` serve a
# produrre un artefatto per il chiamante, e cancellare ciò che ha chiesto sarebbe cancellare il
# suo lavoro. L'aggancio lo legge da qui.
export ARCHE_OTIUM_DEST_IS_DEFAULT=$([[ "$DEST" == "$ROOT/dist" ]] && echo 1 || echo 0)

exec bash "$ARCHE/BuildApp.sh" "${ARGS[@]}"
