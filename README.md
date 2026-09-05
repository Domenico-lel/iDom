# iDom

iDom è un hub personale nativo per iPhone, costruito in SwiftUI con un'interfaccia pulita e coerente con iOS.

## Versione corrente
**0.2.1 — build 3**

### Stato della 0.2.1
Questa versione prosegue lo sviluppo della 0.2 senza aspettare il completamento dei moduli più complessi. **PC Remote e Rete sono presenti nel progetto ma NON sono ancora considerati completi o pronti per l'uso quotidiano.**

### Funzioni disponibili
- Quick Copy: salva testi riutilizzabili e copiali con un tap.
- Parcheggio: salva la posizione dell'auto e torna al punto tramite Apple Maps.
- Scadenze: aggiungi date importanti, visualizza i giorni mancanti e conserva tutto localmente.
- Spend: registra rapidamente spese, importi e categorie e conserva i movimenti localmente.
- Navigazione Home / Tools / Impostazioni.
- Feedback aptico configurabile.

### Messaggi WhatsApp programmati — Beta
Il modulo **Messaggi** permette già di scegliere destinatario, testo, giorno e ora e di salvare la programmazione nell'app.

L'invio WhatsApp completamente automatico non è ancora attivo. Una normale app iOS non può affidarsi all'apertura e al controllo automatico dell'app WhatsApp in background all'ora stabilita. Per rendere l'invio realmente automatico, iDom dovrà comunicare con un backend sicuro collegato a un provider/API WhatsApp autorizzato. Le credenziali API non dovranno essere incorporate direttamente nel codice dell'app.

## Stato moduli
| Modulo | Stato |
| --- | --- |
| Quick Copy | ✅ Disponibile |
| Parcheggio | ✅ Disponibile |
| Scadenze | ✅ Disponibile |
| Spend | ✅ Disponibile |
| Messaggi WhatsApp | 🧪 Beta — programmazione pronta, invio automatico da collegare |
| PC Remote | 🚧 In sviluppo / non completo |
| Rete | 🚧 In sviluppo / non completo |

## Roadmap
- Backend sicuro per Messaggi e integrazione API WhatsApp.
- Notifiche e gestione più completa dei messaggi programmati.
- Completamento progressivo di PC Remote e Rete.
- Nuovi strumenti personali e rifinitura dell'esperienza iDom.

Una funzione viene indicata come disponibile solo quando la sua implementazione principale è presente nel codice.

## Regola di progetto
Il README deve essere aggiornato insieme alle modifiche funzionali del progetto, in modo che descriva sempre lo stato reale di iDom.

## Requisiti
- iOS 17+
- Xcode
- XcodeGen (`brew install xcodegen`)

## Avvio
```bash
xcodegen generate
open iDom.xcodeproj
```

Seleziona il tuo team personale in Signing & Capabilities, collega l'iPhone e avvia l'app.
