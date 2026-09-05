# iDom

iDom è un hub personale nativo per iPhone, costruito in SwiftUI con un'interfaccia pulita e coerente con iOS.

## Versione corrente
**0.2.0 — build 2**

### Novità 0.2
- Quick Copy: salva testi riutilizzabili e copiali con un tap.
- Parcheggio: salva la posizione dell'auto e torna al punto tramite Apple Maps.
- Scadenze: aggiungi date importanti, visualizza i giorni mancanti e conserva tutto localmente.
- Navigazione aggiornata per aprire direttamente i moduli funzionanti.
- Permesso posizione configurato per il modulo Parcheggio.

## Moduli
- PC Remote — in sviluppo
- Rete — in sviluppo
- Quick Copy — disponibile
- Parcheggio — disponibile
- Scadenze — disponibile

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
