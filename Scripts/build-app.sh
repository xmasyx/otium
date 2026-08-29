#!/bin/bash
# Costruisce Otium.app — bundle arm64 per Apple Silicon, avviabile con doppio clic,
# firmato ad-hoc, oppure con l'identità locale «Otium Dev» se l'hai creata con
# Scripts/make-signing-cert.sh. Sul runner di GitHub quell'identità non c'è, quindi le
# release pubblicate sono firmate ad-hoc: è il ramo `else` qui sotto.
# Uso: Scripts/build-app.sh [cartella-destinazione]   (default: ./dist)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$ROOT/dist}"
APP="$DEST/Otium.app"
# La versione la può dettare il chiamante: sul runner di GitHub il tag È la
# versione, e un binario libero di dire un altro numero è un binario che mente
# nella pagina della release. In locale resta il valore scritto qui.
VERSION="${OTIUM_VERSION:-1.1.0}"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

cd "$ROOT"

# ── Apple Silicon, dichiarato e verificato (2026-08-30)
#
# **Il caso.** La v1.1.0 spedita porta una fetta sola — `lipo -archs` sul binario dentro
# `Otium.zip` risponde `arm64` — mentre `install.sh` prometteva falsamente il supporto Intel e
# controllava solo la versione di macOS. Su un Mac Intel, che Otium non supporta, l'installatore
# copiava l'app e poi moriva sull'ultimo controllo dando la colpa alla quarantena.
#
# **La riparazione.** Otium resta arm64 e gira su Apple Silicon. Si ritira la promessa Intel:
# build, installatore, documentazione e release ora dichiarano la stessa architettura che il
# file spedito contiene. `--arch arm64` è esplicito perché il risultato non dipenda dal processore
# della macchina che compila.
#
# **La sonda.** Il percorso del prodotto cambia quando si passa `--arch` (`.build/apple/Products`
# invece di `.build/release`), e scriverlo a mano è il modo di copiare per mesi il binario vecchio
# senza accorgersene. Lo si chiede a `swift build` con `--show-bin-path`, usando gli stessi flag
# della compilazione.
ARCHITETTURA=(--arch arm64)

echo "▸ compilo (release, arm64 per Apple Silicon)…"
swift build -c release --product OtiumApp "${ARCHITETTURA[@]}"
BIN="$(swift build -c release --product OtiumApp "${ARCHITETTURA[@]}" --show-bin-path)/OtiumApp"
[[ -x "$BIN" ]] || { echo "✗ il binario non è dove swift build dice: $BIN"; exit 1; }

echo "▸ icona…"
# Ogni taglia si DISEGNA, non si riduce. La frase «otium cum dignitate» sotto i
# 256 px non è leggibile, e ridurre il 1024 la ridurrebbe a una riga sporca:
# MakeIcon prende la taglia in argomento e sotto la soglia non la scrive.
mkdir -p "$ROOT/.build/icon.iconset"
for size in 16 32 64 128 256 512; do
    swift "$ROOT/Scripts/MakeIcon.swift" \
        "$ROOT/.build/icon.iconset/icon_${size}x${size}.png" "$size" >/dev/null
    double=$((size * 2))
    swift "$ROOT/Scripts/MakeIcon.swift" \
        "$ROOT/.build/icon.iconset/icon_${size}x${size}@2x.png" "$double" >/dev/null
done
swift "$ROOT/Scripts/MakeIcon.swift" "$ROOT/.build/icon-1024.png" 1024 >/dev/null
iconutil -c icns "$ROOT/.build/icon.iconset" -o "$ROOT/.build/Otium.icns"

echo "▸ assemblo il bundle…"
mkdir -p "$DEST"

# ── Nessuna seconda Otium apribile (2026-08-14)
#
# **Il caso.** `dist/Otium.app` e `/Applications/Otium.app` sono lo stesso binario, stesso nome,
# stessa icona: digitando «Otium» in Spotlight non c'è modo di distinguerle, e aprendo quella
# sbagliata il registro degli elementi in background la segue, perché segue l'ultima copia
# aperta. Quel giorno la copia registrata stava in una cartella temporanea poi cancellata, e
# Otium ha smesso di partire all'accensione senza che niente lo dicesse.
#
# **`.metadata_never_index` è stato provato qui e NON funziona**, quindi non è rimasto: quel file
# vale sulla radice di un volume, non su una cartella qualsiasi. Provato lo stesso giorno con la
# copia di staging in `dist/`, `mdfind "kMDItemFSName == 'Otium.app'"` continuava a restituirla.
# Una guardia che non guarda è peggio che nessuna guardia, perché sembra protezione.
#
# Quello che regge è togliere il bersaglio: dopo l'installazione la copia di staging si cancella
# (più sotto), e quando l'installazione non può avvenire perché l'app è viva il bundle nuovo si
# **parcheggia** con un nome che non finisce in `.app`. Una cartella che non è un bundle non la
# apre né Spotlight né Launchpad né `open -a`, e allo script serve comunque solo come artefatto
# intermedio: alla prossima esecuzione lo ricostruisce da capo.
PARCHEGGIO="$DEST/Otium.app.attesa"
rm -rf "$PARCHEGGIO"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Otium"
cp "$ROOT/.build/Otium.icns" "$APP/Contents/Resources/Otium.icns"

# ── L'architettura spedita si verifica, non si spera
#
# Il contratto è una fetta sola, arm64. Il confronto esatto rifiuta sia una fetta mancante sia
# qualunque fetta in più: una build diversa da quella dichiarata fallisce qui, prima della firma,
# invece di farsi scoprire da chi la scarica.
ARCHI_DENTRO="$(lipo -archs "$APP/Contents/MacOS/Otium")"
[[ "$ARCHI_DENTRO" == "arm64" ]] \
    || { echo "✗ il binario deve contenere solo arm64 (contiene: $ARCHI_DENTRO)"; exit 1; }
echo "▸ architettura: $ARCHI_DENTRO"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Otium</string>
    <key>CFBundleDisplayName</key><string>Otium</string>
    <key>CFBundleExecutable</key><string>Otium</string>
    <key>CFBundleIdentifier</key><string>app.otium.mac</string>
    <key>CFBundleIconFile</key><string>Otium</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Vive nella barra dei menu, non nel Dock. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Locale. Nessuna rete, nessun permesso di sistema.</string>
</dict>
</plist>
PLIST

# L'identità stabile serve perché la firma ad-hoc cambia a ogni ricostruzione e macOS non
# riconosce più l'app come la stessa: con un certificato il requisito designato diventa il
# certificato invece di un cdhash che cambia. Si crea una volta sola con
# Scripts/make-signing-cert.sh; senza, si ricade sull'ad-hoc e lo si dice invece di firmare
# di nascosto in un modo diverso da quello atteso.
#
# **Correzione del 2026-08-03.** Qui c'era scritto che l'avviso «Attività app in background»
# nasceva dalla firma ad-hoc. Era falso, e la prova è Kalamos: firmata allo stesso modo, senza
# Team ID, `Developer Name: (null)` nel registro, e nessun avviso. L'avviso veniva dal
# LaunchAgent scritto a mano, che macOS cataloga come *legacy agent*. Curato passando a
# `SMAppService` — vedi `LoginItem` in SystemProbes.swift. La firma stabile resta perché è
# comunque la cosa giusta, non perché curi quello.
IDENTITY="Otium Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    # Le graffe non sono decorative: «${IDENTITY}» senza graffe fa leggere a bash i byte
    # del caporale come parte del nome, e con `set -u` lo script muore su una variabile
    # che esiste (provato qui il 2026-08-02).
    echo "▸ firma con identità stabile «${IDENTITY}»…"
    codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
else
    echo "▸ firma ad-hoc (lancia una volta Scripts/make-signing-cert.sh per quella stabile)…"
    codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
        || echo "  (firma saltata: non blocca l'avvio in locale)"
fi

# ── Installazione in /Applications
#
# **Perché la build non finisce in `dist/`.** «Compilato» non vuol dire «consegnato»: la copia
# che si apre è quella installata, e fermarsi a `dist/` è costato due volte la stessa figura
# (30 e 31 luglio, modifiche verificate su una build che lui non stava usando). Da oggi la
# destinazione è una sola, `/Applications`, che è anche dove `SMAppService` si aspetta di
# trovare un'app registrata all'avvio.
#
# `OTIUM_SKIP_INSTALL=1` salta il passo, per provare una build senza toccare l'installata. È
# l'unico caso in cui in `dist/` resta di proposito un `.app` apribile, perché è esattamente
# quello che hai chiesto: qui la seconda Otium sul disco è voluta, non un incidente.
INSTALLED="/Applications/Otium.app"
if [[ "${OTIUM_SKIP_INSTALL:-0}" == "1" ]]; then
    ESITO="saltata"
    echo "▸ installazione saltata (OTIUM_SKIP_INSTALL=1)"
    echo "  attenzione: in $DEST resta una seconda Otium apribile"
# `pgrep -f` confronta il modello con **l'intera riga di comando di qualunque processo**, quindi
# senza àncore basta un `grep`, un editor o una sonda che nominano quel percorso per far credere
# che l'app sia viva. Successo il 2026-08-03, e il salto dell'installazione è passato inosservato
# perché il messaggio sembrava sensato. Le àncore chiedono la cosa giusta: *il primo argomento è
# esattamente questo eseguibile?*
elif pgrep -f "^$INSTALLED/Contents/MacOS/Otium( |\$)" >/dev/null; then
    # Sostituire il bundle sotto un processo vivo non si fa: si dice e ci si ferma qui.
    ESITO="rifiutata"
    echo "⚠︎ Otium è in esecuzione da $INSTALLED — esci dall'app e rilancia questo script"
    # Il bundle appena costruito non resta come `.app`: sarebbe una seconda Otium apribile per
    # sbaglio proprio nella finestra in cui l'app installata è viva, cioè il caso in cui una
    # copia di troppo fa più danno. Parcheggiato con un nome che non è un bundle, e tolto dal
    # registro di LaunchServices, che l'aveva preso in carico alla firma.
    if [[ "$DEST" == "$ROOT/dist" ]]; then
        "$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
        mv "$APP" "$PARCHEGGIO"
        STAGING_RIMOSSA=1
        echo "  (il bundle nuovo è parcheggiato in $PARCHEGGIO: non è apribile, lo ricostruisco io al prossimo giro)"
    else
        echo "  (il bundle nuovo resta pronto in $APP)"
    fi
else
    # Graffe obbligatorie anche qui: i puntini di sospensione sono un carattere multibyte
    # attaccato al nome, e con `set -u` `$INSTALLED…` muore su una variabile che esiste
    # (successo il 2026-08-03: il bundle veniva costruito e non installato mai). È la stessa
    # lezione scritta venti righe più su per il caporale — la trappola non è il carattere, è
    # scrivere una variabile nuda accanto a un segno non ASCII.
    ESITO="installata"
    echo "▸ installo in ${INSTALLED}…"
    rm -rf "$INSTALLED"
    ditto "$APP" "$INSTALLED"

    # ── Il doppione di staging non sopravvive all'installazione (2026-08-14)
    #
    # Installata la copia buona, quella in `dist/` non serve più a niente e diventa solo una
    # seconda Otium apribile per sbaglio. Si cancella qui, cioè **solo nel ramo che ha davvero
    # installato**: se la copia installata era viva lo script si è già fermato sopra e il bundle
    # resta dov'è, che è la ragione per cui `dist/` esiste.
    #
    # Il vincolo sulla destinazione non è prudenza generica: `build-app.sh <cartella>` serve a
    # produrre un artefatto altrui (la CI di una release), e cancellare ciò che il chiamante ha
    # chiesto sarebbe cancellare il suo lavoro.
    #
    # `lsregister -u` prima di cancellare: un bundle registrato e poi sparito fa annunciare a
    # macOS un'app disinstallata a ogni login, ed è da lì che tornava l'avviso «Attività app in
    # background».
    if [[ "$DEST" == "$ROOT/dist" ]]; then
        "$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
        rm -rf "$APP"
        STAGING_RIMOSSA=1
        echo "▸ tolta la copia di staging da ${DEST}"
    fi
fi

# ── Il riassunto dice quale copia esiste DAVVERO adesso (2026-08-29)
#
# **Il caso.** Le ultime righe stampavano «installata: /Applications/Otium.app» in tutti e tre i
# rami, cioè anche nei due che non installano niente: con `OTIUM_SKIP_INSTALL=1` e quando l'app
# installata è viva. Chi legge conclude di aver appena sovrascritto l'app che sta usando, e per
# due minuti l'ha creduto qualcuno che stava proprio verificando questo ramo. `/Applications`
# era rimasta a giorni prima, quindi non è il file ad aver mentito: è la riga.
#
# È lo stesso difetto dell'installatore che dava la colpa alla quarantena — una riga che afferma
# un fatto che il ramo eseguito non ha compiuto — e si chiude allo stesso modo: **è il ramo a
# dichiarare cos'è successo**, invece di una riga sola scritta fuori dai rami, che non può
# saperlo.
case "${ESITO}" in
    installata)
        echo "✓ pronto"
        echo "  installata:  $INSTALLED"
        echo "  apri con:  open \"$INSTALLED\""
        [[ "${STAGING_RIMOSSA:-0}" == "1" ]] || echo "  il bundle costruito resta in $APP"
        ;;
    saltata)
        echo "✓ pronto: $APP"
        echo "  NON installata: $INSTALLED non è stata toccata, è quella di prima"
        echo "  apri QUESTA con:  open \"$APP\""
        ;;
    rifiutata)
        echo "✓ costruita, non installata"
        echo "  NON installata: $INSTALLED è viva e non si sostituisce sotto un processo"
        if [[ "${STAGING_RIMOSSA:-0}" == "1" ]]; then
            echo "  il bundle nuovo è parcheggiato in $PARCHEGGIO: esci da Otium e rilancia"
        else
            echo "  il bundle nuovo è in $APP: esci da Otium e rilancia"
        fi
        ;;
esac
echo "  registro:  ~/Library/Application Support/Otium/ledger.jsonl"
