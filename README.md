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
- Il progetto XcodeGen è configurato con `xcodeVersion: 15.4` e `objectVersion: 60` per consentire la generazione di un `.xcodeproj` compatibile con Xcode 15.4.
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
rm -rf iDom.xcodeproj
xcodegen generate
open iDom.xcodeproj
```

Seleziona il tuo team personale in Signing & Capabilities, scegli un simulatore compatibile oppure collega l'iPhone e avvia l'app.
