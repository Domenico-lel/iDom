# iDom WhatsApp · invio programmato dal proprio PC

Prima versione per messaggi di testo individuali, usando il proprio account WhatsApp personale tramite WhatsApp Web. iDom invia una programmazione al componente sul PC; dopo la conferma il PC la conserva e la esegue anche se iDom viene chiusa. Non è una funzione ufficiale WhatsApp: può smettere di funzionare dopo aggiornamenti e comporta un rischio di blocco dell’account, dichiarato dal [progetto whatsapp-web.js](https://github.com/wwebjs/whatsapp-web.js#disclaimer).

## Requisiti e limiti

- Windows 10/11 x64 con Microsoft Edge o Google Chrome, Tailscale collegato allo stesso account dell’iPhone.
- PC acceso, non in sospensione, con Internet e utente entrato in Windows. Il blocco schermo va bene. La disconnessione dell’utente, lo spegnimento e la sospensione fermano il componente. Non è richiesto il Mac.
- Il PC deve essere raggiungibile per programmare o annullare: un messaggio non è programmato sul PC finché non arriva la sua conferma. In caso di risposta persa iDom conserva la richiesta e ne riutilizza l’identificativo, senza crearne una seconda.
- Non accende automaticamente il PC. Nessun wake timer o modifica alle opzioni energetiche viene applicato dall’installer.
- Solo testo, massimo 4096 unità UTF-16, un destinatario per messaggio con numero internazionale. Niente gruppi, allegati, invii in massa o ricorrenze.
- Orario almeno 10 secondi nel futuro, entro 366 giorni, massimo 200 messaggi in attesa e 1000 record totali. La cronologia non viene eliminata automaticamente; raggiunto il limite totale la coda va archiviata con il componente fermo, conservando una copia, prima di ricominciare. Non cancellare la coda per risolvere una richiesta incerta: contiene le informazioni contro i duplicati.
- Il timer controlla ogni secondo ma non garantisce precisione al secondo. Se PC o WhatsApp non sono disponibili, attende al massimo 5 minuti dall’orario scelto, poi segna `missed` e non invia in ritardo. I messaggi in coda durante un riavvio seguono la stessa regola.
- Il componente usa un dispositivo collegato: occorre mantenere attivo WhatsApp sul telefono principale e ricollegare il QR in caso di scadenza/revoca della sessione. [Dispositivi collegati](https://faq.whatsapp.com/1317564962315842/).

## Installazione

1. Scarica l’artefatto **iDom-WhatsApp-Windows-x64** dall’ultima esecuzione riuscita di [WhatsApp Windows Companion](https://github.com/Domenico-lel/iDom/actions/workflows/whatsapp.yml). Serve accesso a GitHub; disponibilità 30 giorni. Estrai tutta la cartella. Include Node.js e le dipendenze; non occorre installare Node separatamente.
2. Apri PowerShell **come amministratore con il tuo stesso account Windows**, poi entra nella cartella estratta. Lo script non è firmato: se bloccato, sblocca quel file e limita l’eventuale modifica della policy alla finestra corrente:

   ```powershell
   Unblock-File -LiteralPath .\Installa-WhatsApp.ps1
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
   .\Installa-WhatsApp.ps1
   ```

3. Il programma viene copiato in `C:\Program Files\iDom WhatsApp`, con scrittura riservata ad amministratori/SYSTEM. Sessione, chiave e coda risiedono in `%LOCALAPPDATA%\iDom WhatsApp`, con permessi per il tuo utente, amministratori e SYSTEM. Il task **iDom WhatsApp** parte al login con privilegi limitati, non come SYSTEM; si riavvia dopo un’uscita imprevista. Chromium usa la propria sandbox senza `--no-sandbox`.
4. Nella finestra compare il QR. Allarga PowerShell se il codice va a capo. Su iPhone: **WhatsApp → Impostazioni → Dispositivi collegati → Collega un dispositivo**. Scansiona il QR dal PC. La sessione resta locale, nella cartella protetta; il collegamento può sincronizzare dati WhatsApp sul PC come un normale dispositivo collegato.
5. Pubblica il componente esclusivamente nella tua rete Tailscale:

   ```powershell
   & "$env:ProgramFiles\Tailscale\tailscale.exe" serve --bg --https=8444 http://127.0.0.1:47322
   ```

   Abilita Serve/HTTPS dal collegamento eventualmente mostrato. Non usare Funnel e non aprire porte pubbliche. La porta 8444 deve essere libera; PC Remote continua sulla 8443.
6. In **iDom → Messaggi → Collega WhatsApp sul PC**, inserisci l’indirizzo completo `https://nomepc.nome-rete.ts.net:8444` e la **nuova chiave WhatsApp** di 64 caratteri mostrata dall’installer. Non usare la chiave di PC Remote. Salva verifica versione e ruolo del componente prima di memorizzare le credenziali nel portachiavi dell’iPhone.
7. Programma una prima prova **al tuo numero**, almeno due minuti nel futuro. Dopo che appare **Programmato sul PC**, chiudi iDom e blocca l’iPhone. Lascia il PC acceso. Controlla la chat dopo l’orario; poi ripeti da rete mobile con Tailscale attivo. Questa prova reale richiede il tuo collegamento QR: i test automatici non usano né inviano messaggi da account reali.

Per rivedere il QR o la chiave:

```powershell
& "$env:ProgramFiles\iDom WhatsApp\Collega-WhatsApp.ps1"
```

Per recuperare solo la chiave:

```powershell
(Get-Content -LiteralPath "$env:LOCALAPPDATA\iDom WhatsApp\config.json" -Raw | ConvertFrom-Json).token
```

Non inviare chiavi, QR o cartelle di sessione in chat, screenshot pubblici o repository.

## Stati e affidabilità

- `queued`: salvato sul PC, annullabile tramite API autenticata.
- `sending`: il tentativo è iniziato; non più annullabile.
- `submitted`: WhatsApp Web ha restituito un identificativo; non equivale a consegna al destinatario.
- `delivered` / `read`: ricevuta la relativa conferma WhatsApp, quando disponibile. Le conferme possono non arrivare o non essere recuperate dopo un riavvio.
- `uncertain`: timeout, errore ambiguo o riavvio durante l’invio. **Nessun retry automatico**: verifica la chat prima di programmare di nuovo.
- `failed`: numero non trovato, senza invio.
- `missed`: tolleranza di 5 minuti superata senza iniziare l’invio.
- `cancelled`: annullamento confermato dal PC.
- `simulated`: nessun invio reale; usato nei test.

La coda JSON viene scritta su file temporaneo, sincronizzata e rinominata prima di confermare una modifica. Prima di chiamare WhatsApp viene salvato `sending`. Un riavvio trasforma un tentativo interrotto in `uncertain`, senza reinviarlo. Il sistema privilegia evitare duplicati: non promette consegna esattamente una volta. La perdita del disco, la revoca della sessione o un errore di WhatsApp non possono essere risolti dal solo scheduler. I contenuti non vengono stampati nei log del servizio.

Le vecchie bozze iDom restano leggibili e non vengono inviate automaticamente. In presenza di una richiesta incerta puoi correggere la chiave per lo stesso PC, ma non cambiare destinazione finché la richiesta non è risolta. La richiesta temporaneamente in attesa di conferma rimane sull’iPhone senza chiave; il collegamento è nel portachiavi. Rimuovere il collegamento nell’app **non cancella i messaggi già programmati sul PC** e non revoca la sessione WhatsApp.

## Sicurezza e dati

Il servizio ascolta solo su `127.0.0.1:47322`, dietro Tailscale Serve. Ogni endpoint, incluso QR e stato, richiede un Bearer token casuale di 256 bit. Rifiuta richieste browser con Origin/Fetch Metadata, corpi oltre 32 KiB, destinazioni non numeriche e comandi non previsti. Nessuna esecuzione di shell o API per sfogliare tutte le chat. La libreria accede comunque al profilo WhatsApp Web collegato: non dare la chiave ad altri. Le regole della tua rete Tailscale devono consentire l’accesso solo ai dispositivi autorizzati.

Endpoint: `GET /v1/status`, `GET /v1/qr` per il collegamento locale guidato, `POST /v1/jobs` con UUID, numero, testo e timestamp UTC in millisecondi; `POST /v1/jobs/{id}/cancel` con `{}`. UUID e payload sono persistenti: stessa richiesta = stesso record; UUID riutilizzato con contenuto diverso = errore.

## Fermare, aggiornare e rimuovere

Esegui `Disinstalla-WhatsApp.ps1` come amministratore. Ferma e rimuove solo il task WhatsApp; conserva sessione e coda. Per aggiornare esegui poi il nuovo installer. I messaggi ancora in attesa potranno partire al riavvio secondo la tolleranza documentata. Un invio già consegnato a WhatsApp non può essere ritirato fermando il programma.

Per rimuovere definitivamente: annulla prima i messaggi in coda, ferma il componente, revoca il dispositivo da WhatsApp sull’iPhone, esegui `tailscale serve --https=8444 off`, poi elimina solo le cartelle dedicate `iDom WhatsApp` da Program Files e LocalAppData. Non usare `tailscale serve reset`: interferirebbe con PC Remote. Le sessioni non sono salvate in Git né negli artefatti della build.

## Verifica per sviluppatori

`npm ci --ignore-scripts` installa le versioni bloccate. `npm test` verifica coda, annullamento, deduplica dopo restart, indisponibilità, scritture fallite, autenticazione HTTP e protezione da richieste browser con adapter fittizi. `node index.mjs --data <cartella-di-prova> --init` e poi `node index.mjs --data <cartella-di-prova> --dry-run` avviano il servizio senza caricare WhatsApp. La simulazione ha una coda separata. CI verifica Windows e Linux, la sintassi PowerShell 5.1, il pacchetto e l’avvio di Edge su una pagina vuota, senza account WhatsApp.
