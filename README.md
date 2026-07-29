# 🔦 Scheda Accesa per Chrome / Chrome Active Tab Glow

*Un bagliore colorato intorno alla scheda attiva, e le scritte/icone spente della barra di Chrome diventano più leggibili — pensato per l'accessibilità visiva.*
*A colored glow around the active tab, and Chrome's dim UI text/icons become more readable — built for visual accessibility.*

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow?logo=buy-me-a-coffee&logoColor=white)](https://www.buymeacoffee.com/tures1955)

---

## 🇮🇹 Italiano

Disegna un bagliore colorato intorno alla scheda di Google Chrome attualmente
attiva, e schiarisce selettivamente il testo e le icone (non lo sfondo) sia
nella striscia delle schede sia nella barra degli strumenti — utile per
individuare a colpo d'occhio qual è la scheda attiva e per leggere meglio
scritte e icone spente su un tema scuro.

Non tocca mai il contenuto delle pagine web: agisce solo sulla "cornice" di
Chrome (schede e barra strumenti).

Nato per un bisogno reale di accessibilità visiva, e condiviso perché può
essere utile a chiunque altro abbia lo stesso problema.

### Requisiti

- **Windows 10 o 11**, **Google Chrome** (non funziona con Edge o altri
  browser basati su Chromium: usa dettagli specifici di come Chrome espone
  la sua interfaccia).
- Nessuna installazione, nessun diritto di amministratore richiesto.

### Come iniziare

Scarica i file, poi apri **`AVVIA regolazione Chrome.cmd`** (doppio clic):
si apre un pannello con delle manopole per scegliere colore del bagliore,
forma e quanto si accendono le scritte — le modifiche si vedono subito, in
tempo reale.

Chiudendo il pannello (anche solo con la X) le tue scelte vengono salvate e
il motore silenzioso riparte da solo in automatico.

**La primissima volta che il motore silenzioso parte, si installa da solo**
nella cartella di avvio automatico di Windows: da quel momento in poi si
accende da solo ad ogni accensione del PC, senza che tu debba fare nient'altro.

Per fermarlo definitivamente (motore + avvio automatico), esegui
`ferma-bagliore.ps1`.

### Codice sorgente

Il codice e' tutto qui, in chiaro, negli script `.ps1` — puoi leggerlo prima
di eseguirlo, o modificarlo come preferisci:

- `motore-contrasto.ps1` — il motore silenzioso (nessun pannello, gira in
  background e si auto-installa al primo avvio)
- `regola-bagliore.ps1` — il pannello di regolazione con anteprima dal vivo
- `ferma-bagliore.ps1` — ferma tutto e toglie l'avvio automatico
- `impostazioni-bagliore.json` — dove restano salvate le tue scelte

### Cose da sapere

- Funziona leggendo la struttura di accessibilità di Chrome (la stessa
  tecnologia usata dai lettori di schermo): se una futura versione di
  Chrome cambia profondamente quella struttura, l'effetto potrebbe smettere
  di funzionare finché lo script non viene aggiornato.
- Se un'altra finestra copre Chrome (anche solo in parte), il bagliore si
  spegne automaticamente in quel punto — è voluto, per non disegnare sopra
  finestre che non sono Chrome.
- Il motore resta acceso anche quando lavori in un'altra applicazione:
  mostra sempre l'ultima scheda Chrome vista, finché quella finestra esiste
  ed è visibile.

### Supporto

Se questo strumento ti è stato utile, puoi offrirmi un caffè:
**[buymeacoffee.com/tures1955](https://www.buymeacoffee.com/tures1955)**

---

## 🇬🇧 English

Draws a colored glow around Google Chrome's currently active tab, and
selectively brightens the text and icons (not the background) in both the
tab strip and the toolbar — useful for spotting the active tab at a glance
and for reading dim text/icons more easily on a dark theme.

It never touches the content of web pages: it only acts on Chrome's own
"frame" (tabs and toolbar).

Born out of a real visual accessibility need, and shared because it might
help someone else with the same problem.

### Requirements

- **Windows 10 or 11**, **Google Chrome** (does not work with Edge or other
  Chromium-based browsers: it relies on specifics of how Chrome exposes its
  own UI).
- No installation, no administrator rights needed.

### Getting started

Download the files, then open **`AVVIA regolazione Chrome.cmd`**
(double-click): a panel opens with sliders to choose the glow color, shape,
and how much the text lights up — changes apply instantly, live.

Closing the panel (even just with the X) saves your choices and restarts
the silent engine on its own.

**The very first time the silent engine starts, it installs itself** into
Windows' startup folder: from then on it turns on by itself at every login,
with nothing else needed from you.

To stop it for good (engine + automatic startup), run `ferma-bagliore.ps1`.

### Source code

All the code is right here, in plain text, in the `.ps1` scripts — read it
before running it, or modify it however you like:

- `motore-contrasto.ps1` — the silent engine (no panel, runs in the
  background, self-installs on first run)
- `regola-bagliore.ps1` — the tuning panel with a live preview
- `ferma-bagliore.ps1` — stops everything and removes the automatic startup
- `impostazioni-bagliore.json` — where your choices are saved

### Things to know

- It works by reading Chrome's own accessibility structure (the same
  technology screen readers use): if a future Chrome version changes that
  structure significantly, the effect might stop working until the script
  is updated.
- If another window covers Chrome (even partially), the glow turns off
  automatically in that spot — this is intentional, so it never draws over
  a window that isn't Chrome.
- The engine stays on even while you're working in another application: it
  keeps showing the last Chrome tab it saw, as long as that window still
  exists and is visible.

### Support

If this tool was useful to you, you can buy me a coffee:
**[buymeacoffee.com/tures1955](https://www.buymeacoffee.com/tures1955)**

## License

[MIT](./LICENSE)
