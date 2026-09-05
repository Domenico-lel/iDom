# iDom

iDom è un hub personale nativo per iPhone, scritto in SwiftUI. I dati dei quattro strumenti personali sono salvati sul dispositivo; non serve un account o un server.

## Versione corrente
**0.4.0 — build 6**

## Strumenti personali

### Quick Copy
- Aggiungi testi con nome, anche su più righe e con caratteri speciali.
- Cerca nel nome e nel contenuto; tocca un elemento per copiarlo con conferma visiva.
- Scorri a sinistra per modificare o eliminare; tieni premuto per modificare, condividere o eliminare.
- Le eliminazioni richiedono conferma. Il feedback aptico rispetta l'interruttore in Impostazioni.
- I testi della versione 0.2.1 vengono migrati una sola volta in JSON, con identificatori stabili. Il vecchio archivio rimane come backup; non vengono aggiunti dati di esempio ai nuovi utenti.

### Parcheggio
- Salva la posizione corrente dopo il consenso alla localizzazione.
- Visualizza il punto sulla mappa, data/ora del salvataggio e precisione indicativa.
- Aggiungi una nota (piano, posto, riferimento), salvata automaticamente.
- Apri le indicazioni a piedi in Apple Maps.
- Aggiorna o rimuovi il parcheggio con conferma. Un tentativo GPS fallito non sovrascrive la posizione precedente; l'aggiornamento conserva la nota.
- La ricerca si arresta dopo 20 secondi o uscendo dalla schermata. Vengono accettate posizioni recenti con precisione entro 100 metri; con posizione approssimativa o al chiuso può essere necessario riprovare e abilitare Posizione esatta.
- Nessun rilevamento continuo o in background. Mappe e indicazioni dipendono dalla disponibilità dei servizi Apple e della connessione.

### Scadenze
- Aggiungi e modifica titolo e data, cerca nell'elenco, completa e riapri una scadenza.
- Filtri Da fare/Completate e indicazioni Oggi, Domani, Scaduta o giorni mancanti.
- Attiva Ricordami e scegli data e ora della notifica locale, indipendenti dalla data della scadenza. La richiesta del permesso compare solo quando salvi un promemoria.
- Senza permesso puoi salvare disattivando Ricordami; il modulo mostra anche il collegamento alle impostazioni delle notifiche.
- Modifica, completamento ed eliminazione aggiornano o cancellano il relativo promemoria. Riaprendo una scadenza, un promemoria ancora futuro viene riprogrammato; se è passato, modificalo per riceverne uno nuovo.
- Vengono programmati i prossimi 60 promemoria al massimo, rispettando lo spazio disponibile per le notifiche dell'app. Se ce ne sono altri, un avviso invita a riaprire iDom periodicamente: la coda viene aggiornata all'apertura e al ritorno in primo piano.
- La notifica può arrivare con l'app chiusa. La presentazione dipende dalle impostazioni iOS (permessi, Full immersion, riepiloghi). Toccandola si apre iDom; entra in Scadenze per gestire l'elemento.

### Spend
- Aggiungi, modifica ed elimina spese con descrizione, importo in euro, categoria e data.
- Importi positivi fino a 999.999.999,99 €, con virgola o punto e massimo due decimali; niente separatori delle migliaia. Input non validi non vengono salvati.
- Totale del mese selezionato oppure di tutto lo storico, filtro categoria e riepilogo per categoria. I totali seguono i filtri e sono calcolati in centesimi.
- Usa le frecce per cambiare mese; tocca un movimento per modificarlo e scorri a sinistra per eliminarlo con conferma.
- I vecchi importi fuori limite restano salvati e modificabili, ma sono segnalati come Da correggere ed esclusi dai totali.
- Spese e scadenze salvate nella 0.2.1 rimangono leggibili senza perdere identificatori o date.

## Altri moduli
| Modulo | Stato |
| --- | --- |
| Messaggi WhatsApp | Beta: salva solo la programmazione, senza invio automatico né promemoria WhatsApp |
| PC Remote | Alimentazione Windows: richiede componente e Tailscale; accensione con ponte Wake-on-LAN |
| Rete | In sviluppo |

Messaggi e Rete non sono stati estesi nella 0.4.0. L'invio WhatsApp automatico richiederà un backend e un provider/API autorizzato.

## PC Remote · novità 0.4.0

- Prima versione per **accendere e spegnere un PC Windows anche fuori casa**, tramite rete privata Tailscale. Nessun controllo schermo/mouse/tastiera in questa versione.
- In iDom: collegamento con indirizzo HTTPS e chiave, stato raggiungibilità, Spegni con conferma e conto alla rovescia di 30 secondi, Annulla spegnimento, Accendi tramite ponte Wake-on-LAN configurato. Nessuno spegnimento viene inviato aprendo la schermata.
- Nuovo componente Windows con avvio automatico prima del login, API limitata all'alimentazione, autenticazione, protezione delle credenziali e pacchetto eseguibile generato dal workflow **PC Remote Companion**. Il pacchetto Windows contiene eseguibile e librerie (`onedir`), installati insieme nella cartella protetta Program Files; non usa estrazione temporanea di librerie quando avviato come SYSTEM. Il componente usa Waitress 3.0.2 su loopback, dietro Tailscale Serve HTTPS privato; il PC non viene esposto pubblicamente.
- **Accendere un PC spento richiede un dispositivo acceso nella sua rete**, Ethernet e supporto Wake-on-LAN da BIOS/driver. Il solo iPhone più il PC spento non bastano. Il ponte può essere Linux/macOS/altro Windows; il router identificato è **ZTE ZXHN F6746G**. Il manuale WINDTRE descrive server VPN e binding IP-MAC, ma non un comando Wake-on-LAN: l’accensione usando solo quel router non è verificata.
- La configurazione PC Remote usa il portachiavi di questo iPhone, senza sincronizzazione; tutti i salvataggi degli strumenti precedenti restano invariati. Rimuovi collegamento elimina le credenziali dall'app; per revocarle anche sul computer va rigenerata la chiave.
- **Guida completa e requisiti:** [Companion/README.md](Companion/README.md), con installazione Windows, ponte di accensione, test in simulazione, aggiornamento, rimozione e verifiche hardware. Gli artefatti Windows sono disponibili nelle esecuzioni del workflow per 30 giorni.

### Verifiche PC Remote

`sh Tests/run-remote-checks.sh` verifica gli indirizzi sicuri, le chiavi, la configurazione e il formato delle risposte. In `Companion`, `python -m unittest discover -s tests -v` verifica autenticazione, ruoli, annullamento, richieste duplicate, formato Wake-on-LAN e richieste HTTP reali con azioni di alimentazione sostituite. Nessun test spegne il computer.

Verifiche locali eseguite: **22 controlli PC Remote**, **16 test del componente** (incluso HTTP reale su loopback senza azioni hardware), **36 controlli sui dati precedenti** e **build iOS Simulator riuscita**. I 16 test del componente sono superati anche su Windows e Linux; l’eseguibile Windows è stato generato e avviato in modalità prova su GitHub. La build firmata 0.4.0 è riuscita ed è stata installata e avviata sull’iPhone collegato. Gli script di installazione usano UTF-8 con BOM per Windows PowerShell 5.1; la guida spiega la policy limitata alla sola sessione.

La prima esecuzione UI della 0.4.0 ha superato i tre test degli strumenti precedenti ma ha rilevato l’accesso negato al portachiavi nella build del simulatore senza firma. La build 6 abilita la firma ad-hoc dei test, distingue l’errore di installazione dal telefono bloccato e aggiunge la prova di salvataggio, riapertura e rimozione delle credenziali sintetiche.

La prova sul PC Windows domestico e da rete mobile richiede installazione del componente, collegamento Tailscale e configurazione hardware Wake-on-LAN. Non è ancora stata eseguita: il software non equivale a un'accensione reale già verificata.

## Dati e compatibilità
- iOS 17 o successivo; interfaccia per iPhone.
- Salvataggi locali in UserDefaults: nessuna sincronizzazione tra dispositivi o esportazione/backup completo integrato. Eliminare l'app elimina anche i dati locali.
- Se un archivio di testi, spese o scadenze non è leggibile, iDom mostra l'errore e blocca le modifiche a quell'archivio, conservando gli originali.
- Le chiavi esistenti di spese, scadenze e parcheggio restano in uso. I nuovi campi delle scadenze sono opzionali per compatibilità con i dati precedenti.

## Sviluppo e avvio
Requisiti: Xcode con piattaforma iOS e un simulatore installato, XcodeGen.

```bash
git pull
xcodegen generate
open iDom.xcodeproj
```

`project.yml` è la fonte di verità. `iDom.xcodeproj` viene generato localmente e non è versionato. Dopo aver rigenerato, riaprilo in Xcode.

Per il simulatore scegli un iPhone simulato e premi ⌘R. Per l'iPhone fisico collega e sblocca il telefono, abilita Modalità sviluppatore e scegli il tuo team con firma automatica.

### Firma locale persistente
`Config/Signing.xcconfig` include facoltativamente `Config/Signing.local.xcconfig`, ignorato da Git. La generazione funziona anche nelle copie pulite senza configurazione personale. Puoi conservare lì il team personale per non perderlo alla rigenerazione:

```xcconfig
DEVELOPMENT_TEAM = IL_TUO_TEAM_ID
CODE_SIGN_STYLE = Automatic
```

Non inserire certificati o credenziali. La configurazione locale esistente del team è stata conservata durante questo aggiornamento. La build per simulatore non richiede un team.

### Configurazione XcodeGen
L'installazione locale di XcodeGen 2.46.0 non trovava i preset (`No "base" settings found`). `settingPresets: none` e le impostazioni esplicite del prodotto evitano la precedente collisione `Multiple commands produce .../.app`: `PRODUCT_NAME` è il nome del target e `MACH_O_TYPE` è `mh_execute`. `ALWAYS_SEARCH_USER_PATHS: NO` elimina il warning sugli headermap tradizionali.

La configurazione Debug usa `-Onone` e simboli di debug per consentire l'ispezione dei sorgenti. Le indicazioni storiche `xcodeVersion: 15.4` e `objectVersion: 60` non garantiscono un progetto apribile con Xcode 15.4: XcodeGen 2.46.0 locale genera il formato 77. Lo sviluppo corrente è verificato con Xcode 26.3.

Se Xcode mostra una sessione sospesa e l'app sembra ferma, interrompi con ■ e prova l'avvio dall'icona sul telefono. Un eventuale `SIGKILL` va diagnosticato dai log: da solo non identifica la causa.

## Verifiche
Controlli di migrazione, persistenza, validazione importi, totali, filtri e pianificazione dei promemoria, con dati temporanei separati da quelli dell'app:

```bash
sh Tests/run-core-checks.sh
```

Build per entrambe le architetture del simulatore:

```bash
xcodebuild -project iDom.xcodeproj -scheme iDom \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/iDom-DerivedData CODE_SIGNING_ALLOWED=NO build
```

Test delle schermate (scegli un simulatore iPhone disponibile in `xcrun simctl list devices available`):

```bash
xcodebuild -project iDom.xcodeproj -scheme iDom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
```

Il workflow GitHub Actions esegue i controlli sui dati, la build e i test delle schermate su un simulatore iPhone disponibile. La sola compilazione può essere senza firma; per eseguire i test che usano il portachiavi occorre la firma ad-hoc (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`), senza certificati personali. Conserva il risultato dei test per 7 giorni.

I test delle schermate aggiungono elementi con nomi univoci e li eliminano al termine. Usare un simulatore di test, non il proprio iPhone.

Prima dell'uso quotidiano sul telefono, verificare il GPS all'aperto, il passaggio ad Apple Maps e una notifica a schermo bloccato con le proprie impostazioni iOS. La compilazione e il simulatore non sostituiscono questi controlli hardware.

## Esito verifiche 0.3.0
- 36 controlli sui dati superati.
- Build per iOS Simulator riuscita; build firmata per iPhone riuscita con Xcode 26.3.
- Test UI superati su [GitHub Actions](https://github.com/Domenico-lel/iDom/actions/runs/33952946892): creazione, modifica, copia, persistenza dopo riavvio, completamento ed eliminazione; apertura del Parcheggio senza posizione. Il servizio del simulatore locale non ha completato l’avvio del runner, quindi l’esecuzione UI è stata verificata su GitHub.
- Versione 0.3.0 installata sull’iPhone 14 Pro e avviata senza debugger. Home e apertura di uno strumento confermate sul telefono.
- GPS reale, indicazioni e ricezione delle notifiche a telefono bloccato richiedono la prova sul dispositivo.

## Regola permanente di progetto
Ogni modifica funzionale o di configurazione deve aggiornare questo README, includendo comportamento, migrazioni, limiti e verifiche effettivamente eseguite.
