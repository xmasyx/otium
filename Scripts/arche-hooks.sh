#!/bin/bash
# Gli agganci di Otium dentro la consegna condivisa di Arche.
#
# Qui sta solo ciò che vale per Otium e per nessun'altra app. Tutto il resto — sintassi degli
# script, cancello dell'italiano, compilazione, bundle, firma, notarizzazione, DMG, pulizia di
# LaunchServices — lo fa `BuildApp.sh`.

# ── Il doppione di staging non sopravvive all'installazione (2026-08-14)
#
# Installata la copia buona, quella in `dist/` non serve più a niente e diventa solo una seconda
# Otium apribile per sbaglio: stesso binario, stesso nome, stessa icona, e digitando «Otium» in
# Spotlight non c'è modo di distinguerle. Quel giorno la copia registrata stava in una cartella
# temporanea poi cancellata, e Otium ha smesso di partire all'accensione senza che niente lo dicesse.
#
# `.metadata_never_index` è stato provato e NON funziona: vale sulla radice di un volume, non su una
# cartella qualsiasi. Una guardia che non guarda è peggio che nessuna guardia, perché sembra
# protezione. Quello che regge è togliere il bersaglio.
#
# `lsregister -u` prima di cancellare: un bundle registrato e poi sparito fa annunciare a macOS
# un'app disinstallata a ogni login, ed è da lì che tornava l'avviso «Attività app in background».
arche_post_install() {
    local root dest lsregister
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    dest="$root/dist/Otium.app"
    lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

    if [[ "${ARCHE_OTIUM_DEST_IS_DEFAULT:-0}" == "1" && -d "$dest" ]]; then
        "$lsregister" -u "$dest" >/dev/null 2>&1 || true
        rm -rf "$dest"
        echo "  tolta la copia di staging da $root/dist"
    fi
}
