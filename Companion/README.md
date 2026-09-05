# PC Remote · alimentazione del PC Windows

Questa prima versione aggiunge **spegnimento, annullamento e accensione Wake-on-LAN**. Non trasmette ancora lo schermo e non controlla mouse, tastiera, volume o programmi.

## Come si collega

- iPhone e PC usano lo stesso account Tailscale. iDom si collega all'indirizzo HTTPS privato del PC e invia una chiave di collegamento.
- Il componente Windows ascolta **solo su 127.0.0.1:47321**. Tailscale Serve lo rende raggiungibile nella rete privata su HTTPS, porta **8443**. Nessuna porta pubblica del router, nessun Funnel, nessuna eccezione HTTP/certificato nell'app.
- Il pacchetto Windows usa la modalità **onedir** di PyInstaller: eseguibile e librerie vengono copiati nella cartella protetta del programma, evitando l’estrazione temporanea di una build onefile durante l’esecuzione privilegiata. [Indicazione del produttore](https://www.pyinstaller.org/en/stable/operating-mode.html).
- Il componente parte prima dell'accesso a Windows, tramite un'attività pianificata come SYSTEM. File e chiave sono in `C:\Program Files\iDom Remote`, con accesso limitato a SYSTEM e amministratori. Dopo la copia, l’installer reimposta anche i permessi dei file e delle librerie affinché ereditino quelli della cartella protetta, prima di eseguire il componente. L'installer non cambia BIOS, risparmio energetico, firmware, firewall o impostazioni del router.
- Per **accendere** serve un secondo dispositivo già acceso nella LAN (ponte): ad esempio Raspberry Pi, NAS compatibile o altro computer. Il componente sul PC spento e la sola app Tailscale non possono ricevere il comando. Non installare il ponte sullo stesso PC da accendere.
- Il PC deve rimanere collegato alla corrente e al cavo Ethernet. L'accensione da arresto completo dipende da scheda madre, firmware e scheda di rete: non è garantita dal solo software. [Microsoft spiega le differenze tra sospensione e arresto](https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/wake-on-lan-feature); [Tailscale descrive il ponte Wake-on-LAN](https://tailscale.com/blog/wake-on-lan-tailscale-upsnap).

Il router domestico è stato identificato dalla foto come **ZTE ZXHN F6746G**. Il [manuale ufficiale WINDTRE](https://www.windtre.it/Document/manuali/modem/WINDTRE_manuale_utente_ZTE_F6746.pdf.docview.pdf) documenta server VPN (OpenVPN/IPSec) e binding IP-MAC, ma non un comando Wake-on-LAN. La presenza di VPN e binding non dimostra da sola il recapito dei pacchetti a un PC spento: un’eventuale soluzione senza ponte richiede una prova sul firmware e sull’hardware reali. Questa versione **non include un'integrazione proprietaria con il router**: non promette l'accensione tramite router senza averne verificato modello e funzioni. Un eventuale router con Wake-on-LAN richiede un'integrazione specifica; non inserire il suo pannello amministrativo nel campo ponte iDom.

## Installazione sul PC Windows 10/11 x64

1. Installa [Tailscale per Windows](https://tailscale.com/download/windows), entra nel tuo account e abilita **Run unattended** dal menu Tailscale, per restare collegato prima dell'accesso a Windows. Installa Tailscale anche sull'iPhone, accedi allo stesso account e attiva la connessione.
2. In [GitHub Actions · PC Remote Companion](https://github.com/Domenico-lel/iDom/actions/workflows/pc-remote.yml), apri l'ultima esecuzione riuscita e scarica l'artefatto **iDom-Remote-Windows-x64**. Occorre accedere a GitHub; l'artefatto resta disponibile per 30 giorni e si può rigenerare con Run workflow. Estrai **tutta** la cartella. Il pacchetto contiene Python nella cartella `_internal` e non richiede di installarlo separatamente: conserva tutta la cartella estratta; al momento non ha una firma Authenticode.
3. Apri PowerShell come amministratore nella cartella estratta, controlla gli script e avvia `./Install-Windows.ps1`. Se il file scaricato è bloccato da Windows, sblocca solo i file verificati usando Proprietà → Sblocca; non disattivare le protezioni del sistema. Se la policy locale impedisce gli script anche dopo lo sblocco, abilita `RemoteSigned` solo per la sessione corrente con `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`; la modifica termina chiudendo PowerShell e non modifica la policy della macchina. Gli script sono UTF-8 con BOM per Windows PowerShell 5.1. L'installer crea e prova il servizio locale, poi mostra la chiave privata da inserire in iDom: **non inviarla in chat e non aggiungerla a Git**.
4. Esegui il comando Tailscale mostrato dall'installer, sempre come amministratore:

   ```powershell
   & "$env:ProgramFiles\Tailscale\tailscale.exe" serve --bg --https=8443 http://127.0.0.1:47321
   ```

   Se richiesto, apri il collegamento mostrato da Tailscale per abilitare HTTPS. La porta 8443 è dedicata a iDom: verifica che non ospiti già un altro servizio. Non usare `funnel`. [Documentazione Serve](https://tailscale.com/docs/reference/tailscale-cli/serve).
5. Su iPhone apri **iDom → PC Remote → Collega il PC**. Inserisci l'indirizzo completo mostrato da Tailscale (`https://nomepc.nome-rete.ts.net:8443`) e la chiave di 64 caratteri. Salva e verifica **PC raggiungibile**. Per il primo collegamento lascia disattivato il ponte se non è stato preparato.

Per leggere di nuovo la chiave, apri come amministratore `C:\Program Files\iDom Remote\config.json`. Per revocare una chiave, ferma/disinstalla il servizio, elimina la configurazione con l'opzione sotto e reinstalla; aggiorna la chiave su iPhone. Rimuovere il collegamento solo nell'app non revoca la chiave sul PC.

### Aggiornamento e rimozione

Esegui come amministratore lo script `Uninstall-Windows.ps1`, poi il nuovo installer. La configurazione viene conservata. Lo script di disinstallazione ferma l'attività e la rimuove, ma conserva i file e la pubblicazione Tailscale per non interferire con aggiornamenti.

Per eliminare anche la chiave: `./Uninstall-Windows.ps1 -RemoveCredentials`. Per rimuovere la sola pubblicazione HTTPS dedicata: `tailscale serve --https=8443 off`. Infine puoi eliminare la cartella iDom Remote. Non usare `tailscale serve reset`, che rimuoverebbe anche altre pubblicazioni.

## Ponte di accensione (Linux, macOS o altro Windows sempre acceso)

Richiede Python 3.9+, Tailscale e questi file di `Companion`. Per un NAS verifica prima che supporti Python e Tailscale o un ambiente equivalente. Non servono privilegi di amministratore per inviare il pacchetto UDP.

1. Riserva nel router l'indirizzo LAN del ponte. Recupera il MAC della **scheda Ethernet del PC**, non quello di Wi-Fi o Tailscale (`Get-NetAdapter` sul PC Windows).
2. Crea un ambiente Python dedicato e installa `requirements.txt`.

   ```sh
   python3 -m venv .venv
   .venv/bin/python -m pip install -r requirements.txt
   .venv/bin/python idom_remote.py --config wake.json --init wake --name "Ponte casa" --mac "02:11:22:33:44:55" --network "192.168.1.20/24"
   .venv/bin/python idom_remote.py --config wake.json
   ```

   **Sostituisci MAC e indirizzo/prefisso** con quelli reali. `--network` identifica il ponte e la sua rete: serve per scegliere la scheda corretta e calcolare l'indirizzo broadcast; non è l'indirizzo del PC da accendere. Su Windows usa `py -m venv .venv` e `.venv\Scripts\python.exe`.
3. Mantieni il processo attivo con il gestore servizi del dispositivo e avvialo automaticamente al boot. Proteggi `wake.json` da altri utenti (creazione POSIX con permessi 0600; su Windows assegna accesso solo all'account del servizio e agli amministratori). Per Linux usa l'esempio `idom-wake.service`, adattando percorso e utente; su macOS/Windows il gestore va configurato per il dispositivo scelto. Il ponte deve rimanere acceso, sveglio e connesso alla stessa LAN del PC.
4. Sul ponte esponi il servizio con `tailscale serve --bg --https=8443 http://127.0.0.1:47321` (su Linux può richiedere sudo). In iDom attiva **Ho un ponte di accensione**, inserisci il suo indirizzo HTTPS Tailscale e la sua chiave da `wake.json`, distinta da quella del PC.
5. Abilita Wake-on-LAN nel BIOS/UEFI e nel driver Ethernet del PC secondo il produttore. Controlla il supporto da arresto completo e il comportamento con Avvio rapido/ErP; non cambiare opzioni alla cieca. Prima prova dalla LAN, poi spegni il Wi-Fi sull'iPhone e prova via rete mobile con Tailscale attivo.

Il pacchetto contiene il MAC configurato, ripetuto 16 volte dopo sei byte FF, inviato tre volte alla porta UDP 9 del broadcast della LAN. Il client non può scegliere MAC, rete, comandi shell o altri bersagli a ogni richiesta. Il ponte e il PC hanno ruoli separati: il ponte non accetta spegnimenti.

## Comportamento e limiti

- **Spegni** richiede conferma. Il componente attende 30 secondi; **Annulla spegnimento** elimina il conto alla rovescia, anche da una successiva apertura dell'app. Quando il comando è già consegnato a Windows l'annullamento non è più disponibile.
- Il countdown è gestito dal componente. Alla scadenza usa `shutdown.exe /s /t 0` senza `/f`; documenti aperti possono bloccare lo spegnimento. Non usiamo un ritardo Windows perché `/t > 0` implica la chiusura forzata delle applicazioni. [Riferimento Microsoft](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/shutdown).
- **Accendi** conferma l'invio del pacchetto, non l'avvio del PC. Lo stato viene interrogato ogni 5 secondi mentre la schermata è attiva. **Non raggiungibile** può significare PC spento, VPN scollegata o servizio non disponibile.
- Le richieste di comando non vengono ritentate automaticamente. Se la conferma non arriva, iDom segnala un esito incerto. Identificatori duplicati sono riconosciuti per 10 minuti durante la stessa esecuzione del componente; il countdown e la cache non sopravvivono a un suo riavvio. Ripetere Spegni durante il countdown non lo prolunga. Gli invii Wake-on-LAN sono limitati a uno ogni 10 secondi.
- Chiavi salvate nel portachiavi iOS, accessibili solo a telefono sbloccato, senza sincronizzazione. Nessun token nei normali log o UserDefaults. Il portachiavi può sopravvivere alla reinstallazione dell'app: usa Rimuovi collegamento per eliminarlo esplicitamente.
- Tutti gli endpoint, anche lo stato, richiedono la chiave. Il server rifiuta chiamate dal browser, richieste troppo grandi e comandi arbitrari. Il client accetta solo HTTPS `*.ts.net`, porta standard o 8443, e rifiuta redirect. Le regole Tailscale devono consentire la connessione solo ai tuoi dispositivi autorizzati; chi possiede contemporaneamente accesso alla rete privata e chiave può inviare i comandi.

## Prove senza spegnere nulla

```sh
python3 -m pip install -r requirements.txt
python3 -m unittest discover -s tests -v
python3 idom_remote.py --config test.json --init pc
python3 idom_remote.py --config test.json --dry-run
```

Il flag `--dry-run` non spegne e non invia pacchetti Wake-on-LAN; lo stato e le conferme segnalano la simulazione. I test iniettano funzioni fittizie anche quando verificano il percorso di spegnimento. Il workflow verifica Linux e Windows e produce l'eseguibile x64. La compilazione e questi test non sostituiscono la prova reale sul PC e sulla rete domestica.

Per validare tutta la catena occorrono: stato via rete mobile, spegnimento annullato, spegnimento reale dopo aver salvato il lavoro, accensione da arresto completo e ritorno a **PC raggiungibile** prima del login. Finché non sono eseguiti, accensione e spegnimento sulla macchina dell'utente restano da verificare.
