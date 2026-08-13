# Come funziona, in dettaglio

Qui stanno le parti che nel [README](../README-it.md) avrebbero trasformato la pagina in un manuale:
quando scade ognuno dei quattro segnali, come riconosce un video, e tutti i comandi da terminale.

*[Read this page in English](how-it-works.md).*

---

## Perché al terminale si crede per meno tempo

Otium crede a quattro segnali diversi che dicono «qui c'è qualcuno seduto», e a ognuno crede solo
per un certo tempo, se poi non tocchi più niente:

| Cosa stai facendo | Come lo capisce | Conta come tempo seduto fino a |
|---|---|---|
| **leggi un terminale o un editor** | in primo piano c'è un terminale o un editor di codice: iTerm2, Terminal, Ghostty, Warp, Alacritty, kitty, WezTerm, Hyper, VS Code, Cursor, Xcode, Zed, IntelliJ, Sublime | **5 minuti** |
| leggi un documento | l'app in primo piano è un lettore, e `lsof` dice quale `.pdf`/`.docx`/`.md` tiene aperto | **15 minuti** |
| guardi un video | un player **in elenco** sta producendo audio, attribuito al processo (helper annidati compresi) | **45 minuti** |
| sei in call | microfono in uso, o telecamera che riprende | **non scade mai** |
| te ne sei andato | nessun segnale, nessun input | non è tempo seduto |

Un terminale resta in primo piano da solo per ore, con un agente che macina, una build, un log che
scorre. Un PDF davanti implica almeno che qualcuno l'abbia aperto per leggerlo. «Terminale acceso,
scrivania vuota» è il più facile dei quattro falsi positivi da innescare, quindi è quello che scade
prima.

Scaduto il segnale l'orologio si ferma, e rientrando non ti viene regalata una pausa che non hai
preso, perché l'assenza vale solo da quando il segnale è scaduto.

## La call è l'unica eccezione, e non scade mai

Una riunione di due ore senza toccare il trackpad è la seduta più lunga della giornata. Se il segnale
scadesse, quelle due ore smetterebbero di contare a metà. Al posto della scadenza c'è un richiamo:
dopo **4 ore** di microfono acceso senza un solo tocco l'app avvisa che qualcosa lo sta tenendo aperto.
Avvisa, non blocca.

## La pausa arretrata arriva più grossa

Se il tempo seduto ha superato il **doppio** dell'intervallo, perché eri in riunione o perché hai
rinviato, quella che scatta è la pausa piena da 5 minuti e non lo snack da 90 secondi. Un ciclo
intero saltato non si ripaga con novanta secondi.

## Come riconosce un video, e il disegno che è costato una prova sul campo

L'elenco dei player è chiuso di proposito: contano solo browser e riproduttori video, mai un processo
qualsiasi che stia suonando. Spotify e Musica sono fuori, perché la musica di sottofondo mentre sei
in cucina non è «essere davanti allo schermo».

Il primo disegno leggeva l'asserzione di sistema *«non spegnere lo schermo»*, quella che i player
alzano durante un video. **I browser Chromium non la alzano affatto.** Con YouTube in riproduzione in
Brave, l'elenco completo delle asserzioni conteneva solo `caffeinate`, `powerd` e WindowServer.

L'audio invece si vede sempre. E chi suona non è il browser, è un helper annidato dentro il suo
bundle, che per il sistema non è un'applicazione, quindi va risalito il percorso dell'eseguibile fino
al `.app` più esterno.

Per vedere cosa riconosce in questo momento:

```bash
/Applications/Otium.app/Contents/MacOS/Otium --presence
```

## Avvio automatico

```bash
/Applications/Otium.app/Contents/MacOS/Otium --install-agent   # registra l'avvio al login
/Applications/Otium.app/Contents/MacOS/Otium --agent-status
/Applications/Otium.app/Contents/MacOS/Otium --remove-agent
```

L'avvio automatico passa da **`SMAppService`**, la via moderna: Otium compare fra le app di
*Impostazioni di Sistema → Generali → Elementi login ed estensioni → Apri al login*, con il suo
interruttore. Se lo spegni da lì, l'app **non** se lo rimette, ti porta all'interruttore e si ferma.

> **Cambiato il 2026-08-03.** Prima l'avvio automatico era un LaunchAgent scritto a mano in
> `~/Library/LaunchAgents`, con `KeepAlive` per far ripartire Otium dopo un `kill -9`. macOS lo
> cataloga come *legacy agent*: finiva nella sezione «Consenti in background» invece che fra le app
> di «Apri al login», attribuito a «Unknown Developer», e faceva ricomparire l'avviso «Attività app
> in background» a ogni ricostruzione del bundle. Il `KeepAlive` è caduto con lui, e la scelta è
> dichiarata: sprangava la finestra sul retro lasciando aperta la porta, perché «Esci da Otium» è
> un'uscita pulita che non faceva scattare niente. La rete che resta è il ripristino a caldo:
> riaperta entro la finestra di grazia, l'app riprende il conto da dov'era.
>
> Chi aveva la versione precedente non deve fare niente, perché il vecchio agent viene tolto da solo
> al primo avvio. A mano, se serve: `--remove-legacy-agent`. Il `--doctor` lo segnala se è
> sopravvissuto.

## Vedere la schermata di pausa senza aspettare mezz'ora

```bash
dist/Otium.app/Contents/MacOS/Otium --demo-break=20        # si spegne da sola dopo 20 s
dist/Otium.app/Contents/MacOS/Otium --snapshot=out.png     # la disegna fuori schermo
```

L'auto-spegnimento non è una comodità: durante il blocco l'app disabilita l'uscita forzata, quindi
una demo che dipendesse da qualcuno che la chiude a mano sarebbe il modo perfetto di lasciare un Mac
inchiodato.

## La sonda del blocco

```bash
swift Scripts/probe-blocker.swift    # con l'app in blocco
```

Si tara da sola costruendo una finestra di misura nota, perché `kCGWindowBounds` non vive nello
stesso spazio di coordinate di `NSScreen.frame`. Su un display in modalità scalata una finestra da
1512×982 punti viene elencata come 1362×884, e confrontare i numeri grezzi fa dichiarare rotta
un'app sana.

## Diagnostica

`Otium --doctor` fa 12 controlli: la cartella dei dati, il registro e la sua integrità, le
impostazioni, la rotazione, i mazzi delle frasi, la progressione, l'istanza unica, l'avvio
automatico, i residui del vecchio LaunchAgent, lo stato del primo avvio, e se la scorciatoia ⌃S si
può registrare.

Lo stesso referto sta dentro l'app, in **Preferenze → Avanzate → «Apri la diagnostica…»**, e viene
allegato da solo dal pulsante «Segnala un problema…» qui accanto. I percorsi diventano `~` prima che
il referto esca dall'app.
