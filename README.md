# iDom

iDom è un hub personale nativo per iPhone, costruito in SwiftUI con un'interfaccia pulita e coerente con iOS.

## Versione corrente
**0.2.1 — build 3**

### Stato della 0.2.1
Questa versione prosegue lo sviluppo della 0.2 senza aspettare il completamento dei moduli più complessi. **PC Remote e Rete sono presenti nel progetto ma NON sono ancora considerati completi o pronti per l'uso quotidiano.** Verranno sviluppati progressivamente nelle versioni successive.

### Funzioni disponibili
- Quick Copy: salva testi riutilizzabili e copiali con un tap.
- Parcheggio: salva la posizione dell'auto e torna al punto tramite Apple Maps.
- Scadenze: aggiungi date importanti, visualizza i giorni mancanti e conserva tutto localmente.
- Navigazione Home / Tools / Impostazioni.
- Feedback aptico configurabile.

## Stato moduli
| Modulo | Stato |
| --- | --- |
| Quick Copy | ✅ Disponibile |
| Parcheggio | ✅ Disponibile |
| Scadenze | ✅ Disponibile |
| PC Remote | 🚧 In sviluppo / non completo |
| Rete | 🚧 In sviluppo / non completo |

## Roadmap
Lo sviluppo può continuare sugli altri strumenti e sull'esperienza generale di iDom mentre PC Remote e Rete vengono completati separatamente. Una funzione viene indicata come disponibile solo quando la sua implementazione principale è presente nel codice.

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
