# iDom

iDom è un hub personale nativo per iPhone, costruito in SwiftUI con un'interfaccia pulita e coerente con iOS.

## Versione corrente
**0.2.1 — build 3**

### Stato della 0.2.1
PC Remote e Rete sono presenti ma non ancora completi. Quick Copy, Parcheggio, Scadenze e Spend sono disponibili; Messaggi WhatsApp è in beta.

### Funzioni disponibili
- Quick Copy: salva testi riutilizzabili e copiali con un tap.
- Parcheggio: salva la posizione dell'auto e torna al punto tramite Apple Maps.
- Scadenze: aggiungi date importanti e visualizza i giorni mancanti.
- Spend: registra rapidamente spese, importi e categorie.
- Navigazione Home / Tools / Impostazioni.

### Messaggi WhatsApp programmati — Beta
Permette di scegliere destinatario, testo, giorno e ora e salvare la programmazione. L'invio automatico richiederà un backend sicuro e un provider/API WhatsApp autorizzato.

## Stato moduli
| Modulo | Stato |
| --- | --- |
| Quick Copy | ✅ Disponibile |
| Parcheggio | ✅ Disponibile |
| Scadenze | ✅ Disponibile |
| Spend | ✅ Disponibile |
| Messaggi WhatsApp | 🧪 Beta |
| PC Remote | 🚧 In sviluppo / non completo |
| Rete | 🚧 In sviluppo / non completo |

## Compatibilità sviluppo
- Deployment target: iOS 17+
- `project.yml` è la fonte di verità: il progetto `iDom.xcodeproj` viene generato localmente e non è versionato.
- `xcodeVersion: 15.4` e `objectVersion: 60` esprimono la configurazione storica; XcodeGen 2.46.0 installato localmente genera comunque `objectVersion: 77`. La compatibilità con Xcode 15.4 non è quindi garantita.
- Per iPhone con versioni iOS più recenti può essere necessario un Xcode più recente per l'esecuzione su dispositivo reale.

## Roadmap
- Backend sicuro per Messaggi e integrazione API WhatsApp.
- Notifiche e gestione più completa dei messaggi programmati.
- Completamento progressivo di PC Remote e Rete.
- Nuovi strumenti personali e rifinitura UX.

## Regola di progetto
Il README deve essere aggiornato insieme alle modifiche funzionali o di configurazione del progetto, in modo che descriva sempre lo stato reale di iDom.

## Requisiti
- iOS 17+
- Xcode
- XcodeGen

## Avvio
```bash
git pull
xcodegen generate
open iDom.xcodeproj
```

Scegli un simulatore compatibile e avvia l'app. Per un iPhone fisico, seleziona anche il tuo team personale in Signing & Capabilities.

## Correzione build Xcode 26.3
L'errore `Multiple commands produce .../Debug-iphonesimulator/.app` e il warning
`duplicate output file` erano causati dal nome prodotto mancante nel progetto
generato, non da sorgenti Swift duplicati. La creazione della cartella app e
l'output del comando `CreateUniversalBinary` puntavano entrambi a `.app`.

L'installazione locale di XcodeGen 2.46.0 segnalava `No "base" settings found`
(e analoghi messaggi per debug, release e iOS). Per non dipendere dai preset
mancanti, `project.yml` usa `settingPresets: none` e dichiara esplicitamente
`PRODUCT_NAME: "$(TARGET_NAME)"`, `MACH_O_TYPE: mh_execute`,
`CLANG_ENABLE_MODULES: YES` e `ALWAYS_SEARCH_USER_PATHS: NO`.
Quest'ultima impostazione elimina anche il warning sugli headermap tradizionali.
La scansione dei sorgenti resta unica (`sources: iDom`); non aggiungere gli stessi
file anche come percorsi separati.

Dopo modifiche a `project.yml`, rigenera il progetto con `xcodegen generate`
e riaprilo in Xcode. Le modifiche di configurazione vanno fatte nel file YAML,
perché la rigenerazione sovrascrive le impostazioni del progetto generato.
Per il simulatore non serve selezionare un team di firma.

### Verifica da terminale
```bash
xcodegen generate
xcodebuild \
  -project iDom.xcodeproj \
  -scheme iDom \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/iDom-DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```
La stessa build per simulatore viene eseguita dal workflow GitHub Actions
su push e pull request verso `main`.

Verifica locale completata il 5 settembre 2026: **BUILD SUCCEEDED** con
Xcode 26.3 (17C529), SDK iOS Simulator 26.2, configurazione Debug, architetture
arm64 e x86_64. Nessuna modifica ai sorgenti Swift necessaria. Rimane soltanto
il warning non bloccante `Metadata extraction skipped. No AppIntents.framework
dependency found.`, perché il progetto non integra AppIntents. Questa verifica
riguarda la compilazione; non è un test delle funzionalità o su iPhone fisico.
